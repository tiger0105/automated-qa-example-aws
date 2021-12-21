MANAGER_IP := $(shell terraform output manager-ip)
TEST_API_IP := $(shell terraform output test-api-ip)

default:
	@echo "See Makefile for options/commands"

key:
	ssh-keygen -t rsa -b 2048 -P "" -C automated-qa -f key

prep: key
	(cd .. && npm install)
	rm -rf lambda_source
	mkdir lambda_source
	cp ../index.js lambda_source
	cp -r ../node_modules lambda_source/node_modules

init:
	terraform init

plan: prep
	terraform plan -out terraform.tfplan

apply:
	terraform apply terraform.tfplan

automated-qa-repo:
	git clone git@github.com:kiasaki/automated-qa.git automated-qa || true
	(cd automated-qa && git pull) || true

ssh-manager:
	ssh op@$(MANAGER_IP) -i key

deploy-manager: automated-qa-repo
	ssh-add key
	(cd automated-qa && git subtree push --prefix manager op@$(MANAGER_IP):app.git master)

ssh-test-api:
	ssh op@$(TEST_API_IP) -i key

deploy-test-api: automated-qa-repo
	ssh-add key
	(cd automated-qa && git subtree push --prefix test-service op@$(TEST_API_IP):app.git master)

setupdb-manager:
	ssh op@$(MANAGER_IP) -i key "DATABASE_URL=postgres://admin:admin@localhost:5432/app node app/scripts/setupDatabase.js"

setupdb-test-api:
	ssh op@$(TEST_API_IP) -i key "DATABASE_URL=postgres://admin:admin@localhost:5432/app node app/scripts/setupDatabase.js"
