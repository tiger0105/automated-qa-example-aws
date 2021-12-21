## Automated QA: Example use & deployment to AWS

The `index.js` file contains tests verifying that the simple "todo" API
implemented [here](https://github.com/lambdagrid/automated-qa/tree/master/test-service)
works as designed.

Assertions are declared as simple `flow`, `act` and `check` statements (those
are explained in greater detail in this project's top level readme).

### Deployment

In the `ops/` folder, all the (terraform) files nessasary to deploy:

- This checklist (`index.js`) as an AWS Lambda function.
- The "todo" API we are testing (to an EC2 instance with a local PostgreSQL)
- The Automated QA Manager API (to an EC2 instance with a local PostgreSQL)

_In a more realistic scenario you would only need to deploy this repo to AWS
Lambda as you would already have your own API hosted somewhere. Additionaly
you wouldn't need to deploy the Automated QA Manager API as you can use the
hosted version._

**Initial run**

Make sure you have Terraform installed ([Download](https://www.terraform.io/downloads.html)).

Then head to the `ops/` directory and copy the `terraform.tfvars.example` file to `terraform.tfvars`
filling in the nessesary information (AWS Credentials).

```
cd ops
cp terraform.tfvars.example terraform.tfvars
```

The next step is to generate a plan of the actions to take:

```
make plan
```

On this command completes successfully it will have created a `terraform.tfplan`
file representing exactly the changes it just presented you after running "plan".

We can "apply" those changes by running:

```
make apply
```

If you see something like the text below, then you've sucessfully provisionned
all the necessary ressources for this example.

```
Apply complete! Resources: N added, 0 changed, 0 destroyed.

Outputs:

manager-ip = 52.201.0.0
test-api-ip = 54.144.0.0
text-api-checklist-url = https://abc123c7zj.execute-api.us-east-1.amazonaws.com/prod
```

The before last step is to deploy the `test-api` and `manager` source code to
those 2 VMs we just created. You can do this using:

```
make deploy-manager
make deploy-test-api
```

The last step is to run the inital "database setup" script for both of these apps:

```
make setupdb-manager
make setupdb-test-api
```

That's it! You should be able to use the manager api, test todo api & checklist
service. To get the IPs & DNS names for those simply run `terraform output`.
