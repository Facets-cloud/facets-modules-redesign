package test

import (
	"encoding/json"
	"fmt"

	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

var (
	instanceName = "test-aws-secret-manager"

	environment = map[string]interface{}{
		"namespace":   "default",
		"unique_name": "k8s",
	}
)

type Instance struct {
	// Convert your input json to go struct and put the values here - You can use this for conversion https://mholt.github.io/json-to-go/
}

func TestAwsSecretManager(t *testing.T) {
	// add the parallel line if you wanna execute this test in parallel
	t.Parallel()

	// Reading the test instance json file
	file, e := os.ReadFile("test.json")
	if e != nil {
		fmt.Println("Failed to read test.json file")
		os.Exit(1)
	}

	// Unmarshalling the json
	instance := Instance{}
	json.Unmarshal([]byte(file), &instance)

	// Convert to json string
	marshelledInstance, _ := json.Marshal(instance)
	instanceString := string(marshelledInstance)

	// Instantiate the terraform object with the desired options
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../",
		Vars: map[string]interface{}{
			"instance":      instanceString,
			"instance_name": instanceName,
			"environment":   environment,
		},
	})

	// Delete the test env after success or failure
	defer terraform.Destroy(t, terraformOptions)

	// Create the terraform environment for testing
	terraform.InitAndApply(t, terraformOptions)

	// validate outputs
	ValidateOutputs(t, terraformOptions, instance)
}

// ValidateOutputs will run test cases
func ValidateOutputs(t *testing.T, opts *terraform.Options, instance Instance) {
	// Your validation logic will go here
}
