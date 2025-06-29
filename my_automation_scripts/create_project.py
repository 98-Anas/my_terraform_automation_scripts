#!/usr/bin/env python3
import os
import subprocess
import logging
from enum import Enum, auto

class State(Enum):
    SETUP = auto()
    GENERATE = auto()
    DEPLOY = auto()
    DESTROY = auto()

    @classmethod
    def from_string(cls, state_str):
        try:
            return cls[state_str]
        except KeyError:
            logging.warning(f"Invalid state '{state_str}' in state file, defaulting to SETUP")
            return cls.SETUP

class ProjectManager:
    def __init__(self):
        self.automation_script_dir = "/home/zonzo/my_automation_scripts"
        self.work_dir = "/home/zonzo/workindir"
        self.state_file = "/tmp/terraform_deploy_state.env"
        self.current_state = State.SETUP
        self.selected_env = "none"
        self.project_dir = ""
        self.setup_logging()
        
    def setup_logging(self):
        logging.basicConfig(
            filename='terraform_deploy.log',
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        logging.info("Initializing Project Manager")

    def load_state(self):
        if os.path.exists(self.state_file):
            with open(self.state_file, 'r') as f:
                for line in f:
                    if line.startswith("DEPLOY_STATE="):
                        state_str = line.strip().split('=')[1]
                        self.current_state = State.from_string(state_str)
                    elif line.startswith("SELECTED_ENV="):
                        self.selected_env = line.strip().split('=')[1]
        else:
            self.save_state(State.SETUP, "none")

    def save_state(self, state, env):
        self.current_state = state
        self.selected_env = env
        with open(self.state_file, 'w') as f:
            f.write(f"DEPLOY_STATE={state.name}\n")
            f.write(f"SELECTED_ENV={env}\n")

    def verify_project_structure(self):
        if not self.project_dir:
            return False
            
        required_dirs = [
            "environments/pre-prod",
            "environments/prod",
            "modules/networking",
            "modules/compute",
            "modules/logging"
        ]
        
        for dir_path in required_dirs:
            if not os.path.exists(os.path.join(self.project_dir, dir_path)):
                logging.warning(f"Missing directory: {dir_path}")
                return False
        return True

    def setup_project(self):
        dir_name = input("Enter project directory name (e.g. yourprojectname): ").strip()
        if not dir_name:
            print("Project name cannot be empty")
            return False
            
        self.project_dir = os.path.join(self.work_dir, dir_name)
        
        if os.path.exists(self.project_dir):
            if self.verify_project_structure():
                logging.info(f"Using existing project at {self.project_dir}")
                return True
            else:
                logging.warning("Project exists but structure is invalid")
                return False
        
        logging.info(f"Creating new project at {self.project_dir}")
        try:
            result = subprocess.run(
                [os.path.join(self.automation_script_dir, "set_terraform_env.sh")],
                cwd=self.work_dir,
                check=True
            )
            return result.returncode == 0
        except subprocess.CalledProcessError as e:
            logging.error(f"Failed to setup project: {e}")
            return False

    def generate_environment(self, env):
        if env not in ["pre-prod", "prod"]:
            logging.error(f"Invalid environment: {env}")
            return False
            
        logging.info(f"Generating {env} environment")
        script_path = os.path.join(self.automation_script_dir, f"generate_{env}_templates.sh")
        
        if not os.path.exists(script_path):
            logging.error(f"Generator script not found: {script_path}")
            return False
            
        try:
            result = subprocess.run([script_path], check=True, cwd=self.project_dir)
            if not self.format_terraform():
                return False
            return result.returncode == 0
        except subprocess.CalledProcessError as e:
            logging.error(f"Failed to generate {env}: {e}")
            return False

    def format_terraform(self):
        logging.info("Formatting Terraform files")
        try:
            subprocess.run(
                ["terraform", "fmt", "-recursive"],
                cwd=self.project_dir,
                check=True
            )
            return True
        except subprocess.CalledProcessError as e:
            logging.error(f"Formatting failed: {e}")
            return False
        except FileNotFoundError:
            logging.error("Terraform command not found")
            return False

    def deploy_environment(self, env):
        if env not in ["pre-prod", "prod"]:
            logging.error(f"Invalid environment: {env}")
            return False
            
        env_dir = os.path.join(self.project_dir, "environments", env)
        if not os.path.exists(env_dir):
            logging.error(f"Environment directory not found: {env_dir}")
            return False
            
        logging.info(f"Deploying to {env} environment")
        
        try:
            # Initialize
            subprocess.run(
                ["terraform", "init", "-backend-config=backend.conf"],
                cwd=env_dir,
                check=True
            )
            
            # Validate
            subprocess.run(
                ["terraform", "validate"],
                cwd=env_dir,
                check=True
            )
            
            # Plan
            subprocess.run(
                ["terraform", "plan", "-out=tfplan"],
                cwd=env_dir,
                check=True
            )
            
            # Apply
            confirm = input(f"Apply changes to {env}? (y/n) ").strip().lower()
            if confirm == 'y':
                subprocess.run(
                    ["terraform", "apply", "tfplan"],
                    cwd=env_dir,
                    check=True
                )
                return True
            return False
            
        except subprocess.CalledProcessError as e:
            logging.error(f"Deployment failed: {e}")
            return False

    def destroy_environment(self, env):
        if env not in ["pre-prod", "prod"]:
            logging.error(f"Invalid environment: {env}")
            return False
            
        env_dir = os.path.join(self.project_dir, "environments", env)
        if not os.path.exists(env_dir):
            logging.error(f"Environment directory not found: {env_dir}")
            return False
            
        logging.info(f"Destroying {env} environment")
        
        try:
            # Plan destruction
            subprocess.run(
                ["terraform", "plan", "-destroy", "-out=destroy_plan"],
                cwd=env_dir,
                check=True
            )
            
            # Apply destruction
            confirm = input(f"Destroy ALL resources in {env}? (y/n) ").strip().lower()
            if confirm == 'y':
                subprocess.run(
                    ["terraform", "apply", "destroy_plan"],
                    cwd=env_dir,
                    check=True
                )
                return True
            return False
            
        except subprocess.CalledProcessError as e:
            logging.error(f"Destruction failed: {e}")
            return False

    def show_menu(self):
        print("\n====================================")
        print(" AWS Landing Zone Deployment Manager ")
        print("====================================")
        print(f" Current State: {self.current_state.name}")
        print(f" Environment: {self.selected_env}")
        print("------------------------------------")
        
        if self.current_state == State.SETUP:
            print("1) Setup Project Structure")
            print("2) Generate Pre-Prod Environment")
            print("3) Generate Prod Environment")
        elif self.current_state == State.GENERATE:
            print("1) Go to Deploy Menu")
            print("2) Generate Different Environment")
        elif self.current_state == State.DEPLOY:
            print(f"1) Apply {self.selected_env} Environment")
            print("2) Go to Destroy Menu")
            print("3) Go Back to Setup Menu")
        elif self.current_state == State.DESTROY:
            print(f"1) Destroy {self.selected_env} Environment")
            print("2) Go Back to Setup Menu")
            print("3) Go Back to Deploy Menu")
        
        print("\n0) Exit")
        print("====================================")
        
        try:
            choice = input("Select option: ").strip()
            if not choice.isdigit():
                raise ValueError
            choice = int(choice)
            self.handle_choice(choice)
        except ValueError:
            print("Invalid input. Please enter a number.")
            self.show_menu()

    def handle_choice(self, choice):
        if choice == 0:
            exit(0)
            
        if self.current_state == State.SETUP:
            if choice == 1:
                if self.setup_project():
                    self.save_state(State.GENERATE, "none")
            elif choice == 2:
                if self.generate_environment("pre-prod"):
                    self.save_state(State.DEPLOY, "pre-prod")
            elif choice == 3:
                if self.generate_environment("prod"):
                    self.save_state(State.DEPLOY, "prod")
            else:
                print("Invalid option")
                
        elif self.current_state == State.GENERATE:
            if choice == 1:
                self.save_state(State.DEPLOY, self.selected_env)
            elif choice == 2:
                self.save_state(State.SETUP, "none")
            else:
                print("Invalid option")
                
        elif self.current_state == State.DEPLOY:
            if choice == 1:
                if self.deploy_environment(self.selected_env):
                    self.save_state(State.DESTROY, self.selected_env)
            elif choice == 2:
                self.save_state(State.DESTROY, self.selected_env)
            elif choice == 3:
                self.save_state(State.SETUP, "none")
            else:
                print("Invalid option")
                
        elif self.current_state == State.DESTROY:
            if choice == 1:
                if self.destroy_environment(self.selected_env):
                    self.save_state(State.SETUP, "none")
            elif choice == 2:
                self.save_state(State.SETUP, "none")
            elif choice == 3:
                self.save_state(State.DEPLOY, self.selected_env)
            else:
                print("Invalid option")
                
        self.show_menu()

    def run(self):
        self.load_state()
        if not self.project_dir or not os.path.exists(self.project_dir):
            if not self.setup_project():
                print("Failed to setup project. Check logs.")
                exit(1)
        self.show_menu()

if __name__ == "__main__":
    print("Run 'tail -f terraform_deploy.log' in another terminal to monitor logs")
    manager = ProjectManager()
    manager.run()