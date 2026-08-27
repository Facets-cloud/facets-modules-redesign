import sys
import os
import json
import base64
import traceback
import boto3
from abc import ABC, abstractmethod
from google.cloud import secretmanager, secretmanager_v1

# -----------------------------
# legacy delegation
# -----------------------------
LEGACY_SCRIPT = (
    "/sources/primary/capillary-cloud-tf/tfmain/scripts"
    "/cloudaccount-fetch-secret/secret-fetcher.py"
)


def delegate_to_legacy():
    """Hand off to the legacy framework's fetcher when it is present.

    On the legacy framework that script already owns this contract, so we let it
    answer rather than reimplementing it here. Uses exec so it inherits this
    process outright: its stdout becomes our stdout verbatim and its exit status
    becomes ours, which is what data.external reads. Does not return on success.

    When it is absent we are on the CRD-driven framework, and everything below
    resolves the same values from the pod environment instead.
    """
    if not os.path.isfile(LEGACY_SCRIPT):
        return False
    python = sys.executable or "python3"
    os.execv(python, [python, LEGACY_SCRIPT] + sys.argv[1:])


# -----------------------------
# config.py
# -----------------------------
def get_env(var, default=None, required=False):
    value = os.getenv(var, default)
    if required and not value:
        raise ValueError(f"{var} is required but not set.")
    return value

def load_deployment_context(path="/sources/deployment_context/deploymentcontext.json"):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f).get("secretsContext", {})
    except (FileNotFoundError, json.JSONDecodeError):
        return {
            "secretManagerRegion": get_env("SECRET_MANAGER_REGION", required=True),
            "gcpSecretManagerProjectId": get_env("GCP_SECRET_MANAGER_PROJECT_ID"),
            "gcpSecretManagerMode": get_env("GCP_SECRET_MANAGER_MODE", default="GLOBAL"),
        }

# -----------------------------
# fetchers/base.py
# -----------------------------
class BaseSecretFetcher(ABC):
    @abstractmethod
    def fetch(self, secret_id: str) -> dict:
        pass

# -----------------------------
# fetchers/aws_fetcher.py
# -----------------------------
class AWSSecretFetcher(BaseSecretFetcher):
    def fetch(self, secret_id: str) -> dict:
        secret_context = load_deployment_context()
        region = secret_context["secretManagerRegion"]
        try:
            client = boto3.client("secretsmanager", region_name=region)
            response = client.get_secret_value(SecretId=secret_id)
            return json.loads(response["SecretString"])
        except Exception as e:
            raise RuntimeError(f"Failed to fetch AWS secret '{secret_id}' from region '{region}': {e}")

# -----------------------------
# fetchers/gcp_fetcher.py
# -----------------------------
class GCPSecretFetcher(BaseSecretFetcher):
    def __init__(self):
        ctx = load_deployment_context()
        self.project = ctx["gcpSecretManagerProjectId"]
        self.region = ctx["secretManagerRegion"]
        self.mode = ctx["gcpSecretManagerMode"]

    def fetch(self, secret_id: str) -> dict:
        if self.mode.upper() == "REGIONAL":
            parent = f"projects/{self.project}/locations/{self.region}/secrets/{secret_id}"
            endpoint = f"secretmanager.{self.region}.rep.googleapis.com"
            client = secretmanager_v1.SecretManagerServiceClient(
                client_options={"api_endpoint": endpoint}
            )
        else:
            parent = f"projects/{self.project}/secrets/{secret_id}"
            client = secretmanager.SecretManagerServiceClient()

        versions = client.list_secret_versions(request={"parent": parent})
        try:
            enabled = next(v for v in versions if v.state.name == "ENABLED")
        except StopIteration:
            raise RuntimeError(f"No ENABLED versions found for secret '{secret_id}' in project '{self.project}'")
        payload = client.access_secret_version(request={"name": enabled.name}).payload
        return json.loads(payload.data.decode("utf-8"))

# -----------------------------
# normalizer.py
# -----------------------------
def normalize(secret: dict, cloud: str) -> dict:
    cloud = cloud.upper()
    if cloud == "AWS":
        return {
            "iamRole": secret.get("iamRole"),
            "externalId": secret.get("externalId")
        }
    elif cloud == "GCP":
        key = secret.get("serviceAccountKey")
        try:
            decoded = json.loads(base64.b64decode(key).decode())
        except (ValueError, TypeError, json.JSONDecodeError):
            decoded = json.loads(key)
        return {
            "project": decoded["project_id"],
            "serviceAccountKey": key
        }
    elif cloud == "AZURE":
        return {
            "subscription_id": secret.get("subscriptionId"),
            "client_id": secret.get("clientId"),
            "tenant_id": secret.get("tenantId"),
            "client_secret": secret.get("clientSecret")
        }
    else:
        raise ValueError(f"Unsupported target cloud: {cloud}")

# -----------------------------
# main.py
# -----------------------------
class CredentialFetcher:
    def __init__(self, account_id, account_cloud):
        self.cp_cloud = get_env("TF_VAR_CP_CLOUD", required=True).lower()
        self.target_cloud = account_cloud.upper()
        self.cluster = get_env("TF_VAR_CP_NAME", required=True)
        self.account_id = account_id

    def get_strategy(self):
        if self.cp_cloud == "aws":
            return AWSSecretFetcher()
        elif self.cp_cloud == "gcp":
            return GCPSecretFetcher()
        else:
            raise ValueError(f"Unsupported CP cloud: {self.cp_cloud}")

    def build_secret_id(self):
        return f"{self.cluster}_backend_accounts_{self.account_id}" if self.cp_cloud == "gcp" else f"{self.cluster}/backend/accounts/{self.account_id}"

    def run(self):
        strategy = self.get_strategy()
        secret_id = self.build_secret_id()
        secret = strategy.fetch(secret_id)
        output = normalize(secret, self.target_cloud)
        print(json.dumps(output, indent=2))

if __name__ == "__main__":
    try:
        delegate_to_legacy()  # does not return when the legacy script is present
        cloud_account_id = sys.argv[1]
        cloud  = sys.argv[2]
        CredentialFetcher(cloud_account_id, cloud).run()
    except Exception as e:
        print(json.dumps({"Error": str(e)}))
        traceback.print_exc()
        sys.exit(1)