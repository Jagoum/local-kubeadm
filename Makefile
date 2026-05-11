.PHONY: help init plan apply destroy venv install-ansible install-collections deploy clean status
.PHONY: ssh-control ssh-worker1 ssh-worker2 ansible-run ansible-verify ansible-tags

# Virtual environment configuration
VENV_DIR := .venv
VENV_PYTHON := $(VENV_DIR)/bin/python3
VENV_PIP := $(VENV_DIR)/bin/pip
VENV_ANSIBLE := $(VENV_DIR)/bin/ansible
VENV_ANSIBLE_PLAYBOOK := $(VENV_DIR)/bin/ansible-playbook
VENV_ANSIBLE_GALAXY := $(VENV_DIR)/bin/ansible-galaxy

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

venv: ## Create Python3 virtual environment (idempotent)
	@if [ -d "$(VENV_DIR)" ]; then \
		echo "Virtual environment already exists at $(VENV_DIR)"; \
	else \
		echo "Creating Python3 virtual environment..."; \
		python3 -m venv $(VENV_DIR); \
		echo "Virtual environment created at $(VENV_DIR)"; \
		echo "To activate: source $(VENV_DIR)/bin/activate"; \
	fi

install-ansible: venv ## Install Ansible in virtual environment (idempotent)
	@echo "Ensuring Ansible is installed..."
	$(VENV_PIP) install --upgrade pip --quiet
	$(VENV_PIP) install ansible --quiet
	@echo "Ansible installed: $$($(VENV_ANSIBLE) --version | head -1)"

install-collections: ## Install Ansible collections (idempotent)
	@echo "Installing Ansible collections..."
	$(VENV_ANSIBLE_GALAXY) collection install -r ansible/requirements.yml

init: ## Initialize Terraform
	@echo "Initializing Terraform..."
	cd terraform && terraform init

plan: ## Plan Terraform changes
	@echo "Planning Terraform changes..."
	cd terraform && terraform plan

apply: ## Apply Terraform changes
	@echo "Applying Terraform changes..."
	cd terraform && terraform apply -auto-approve

destroy: ## Destroy Terraform infrastructure
	@echo "Destroying Terraform infrastructure..."
	cd terraform && terraform destroy -auto-approve

deploy: ## Deploy complete infrastructure (create venv, install ansible, apply terraform)
	@echo "Deploying complete infrastructure..."
	$(MAKE) install-ansible
	$(MAKE) install-collections
	$(MAKE) init
	$(MAKE) apply

clean: ## Clean up generated files and virtual environment
	@echo "Cleaning up..."
	rm -rf terraform/.terraform terraform/*.tfstate terraform/*.tfstate.*
	rm -rf ansible/logs ansible/collections
	rm -rf *.log *.tmp
	rm -rf $(VENV_DIR)

clean-venv: ## Remove only virtual environment
	@echo "Removing virtual environment..."
	rm -rf $(VENV_DIR)

status: ## Check cluster status
	@echo "Checking cluster status..."
	@multipass list
	@echo ""
	@echo "To check Kubernetes cluster status, run:"
	@echo "  multipass shell control-plane"
	@echo "  sudo kubectl get nodes -o wide"
	@echo "  sudo kubectl get pods --all-namespaces"

ssh-control: ## SSH into control plane
	@echo "Connecting to control plane..."
	multipass shell control-plane

ssh-worker1: ## SSH into worker 1
	@echo "Connecting to worker 1..."
	multipass shell worker-1

ssh-worker2: ## SSH into worker 2
	@echo "Connecting to worker 2..."
	multipass shell worker-2

ansible-run: ## Run Ansible playbook manually (requires venv)
	@echo "Running Ansible playbook..."
	$(VENV_ANSIBLE_PLAYBOOK) -i ansible/inventory/hosts.ini ansible/site.yml

ansible-verify: ## Verify Ansible playbook (dry run)
	@echo "Verifying Ansible playbook..."
	$(VENV_ANSIBLE_PLAYBOOK) -i ansible/inventory/hosts.ini ansible/site.yml --check

ansible-tags: ## Run Ansible with specific tags (usage: make ansible-tags TAGS=common,kubernetes)
	@echo "Running Ansible with tags: $(TAGS)"
	$(VENV_ANSIBLE_PLAYBOOK) -i ansible/inventory/hosts.ini ansible/site.yml --tags $(TAGS)

activate: ## Show command to activate virtual environment
	@echo "To activate the virtual environment, run:"
	@echo "  source $(VENV_DIR)/bin/activate"