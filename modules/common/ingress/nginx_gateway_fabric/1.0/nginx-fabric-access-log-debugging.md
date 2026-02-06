# NGINX Gateway Fabric - Data Plane Access Log Debugging Steps

## Environment

- NGINX Gateway Fabric v2.3.0
- GatewayClass: `control-plane`
- NginxProxy resource: `control-plane-nginx-fabric-proxy-config`
- Data plane deployment: `control-plane-control-plane`
- Data plane container: `nginx`

## Step 1: Identify Resources

```bash
# Find NGF pods
kubectl get pods -n default | grep nginx

# Check NginxProxy resource
kubectl get nginxproxies --all-namespaces

# Check current NginxProxy config
kubectl get nginxproxy control-plane-nginx-fabric-proxy-config -o yaml
```

## Step 2: Understand Available Logging Options

```bash
kubectl explain nginxproxy.spec.logging.accessLog
```

Fields:
- `disable` (boolean): Turns off access logging when set to true.
- `format` (string): Custom log format string. If not specified, NGINX default 'combined' format is used. Output goes to `/dev/stdout`.

## Step 3: Enable Access Logs

```bash
kubectl patch nginxproxy control-plane-nginx-fabric-proxy-config \
  --type=merge \
  -p '{"spec":{"logging":{"accessLog":{"disable":false}}}}'
```

## Step 4: Enable Access Logs with Custom Format (Including Service Name)

```bash
kubectl patch nginxproxy control-plane-nginx-fabric-proxy-config \
  --type=merge \
  -p '{"spec":{"logging":{"accessLog":{"disable":false,"format":"$remote_addr - $remote_user [$time_local] \"$request\" $status $body_bytes_sent \"$http_referer\" \"$http_user_agent\" host=$host service=$proxy_host rt=$request_time urt=$upstream_response_time"}}}}'
```

### Log Format Variables

| Variable | Description |
|---|---|
| `$remote_addr` | Client IP address |
| `$remote_user` | Authenticated user |
| `$time_local` | Timestamp |
| `$request` | Full request line (method, URI, protocol) |
| `$status` | HTTP response status code |
| `$body_bytes_sent` | Response body size |
| `$http_referer` | Referer header |
| `$http_user_agent` | User-Agent header |
| `$host` | Requested hostname |
| `$proxy_host` | Upstream name (`<namespace>_<service>_<port>`) |
| `$upstream_addr` | Upstream server IP:port |
| `$request_time` | Total request processing time |
| `$upstream_response_time` | Time waiting for upstream response |
| `$upstream_connect_time` | Time to establish upstream connection |
| `$upstream_header_time` | Time to receive upstream response header |

### Upstream Naming Convention

NGF names upstreams as `<namespace>_<service-name>_<port>`, e.g.:
- `default_control-plane-react_3200`
- `default_agent_8000`

The `$proxy_host` variable resolves to this name.

## Step 5: Verify Config Propagated to Data Plane

```bash
# Check the generated nginx config
kubectl exec deployment/control-plane-control-plane -c nginx \
  -- grep -E 'log_format|access_log' /etc/nginx/conf.d/http.conf

# Check upstream names
kubectl exec deployment/control-plane-control-plane -c nginx \
  -- grep 'proxy_pass' /etc/nginx/conf.d/http.conf
```

## Step 6: View Access Logs

```bash
# Stream logs from data plane
kubectl logs deployment/control-plane-control-plane -c nginx -f

# Filter for HTTP access entries only
kubectl logs deployment/control-plane-control-plane -c nginx -f | grep -E '(GET|POST|PUT|DELETE|PATCH) '
```

## Step 7: Disable Access Logs

```bash
kubectl patch nginxproxy control-plane-nginx-fabric-proxy-config \
  --type=merge \
  -p '{"spec":{"logging":{"accessLog":{"disable":true}}}}'
```
