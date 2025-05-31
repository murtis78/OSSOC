#!/bin/bash

# IRIS Velociraptor Module Installation Script
# This script downloads and installs the Velociraptor module for IRIS

set -e

# Configuration
GITHUB_REPO="socfortress/iris-velociraptorartifact-module"
MODULE_DIR="./modules/iris-velociraptor"
TEMP_DIR="/tmp/iris-velociraptor-install"

echo "🚀 Installing IRIS Velociraptor Module..."

# Create module directory
mkdir -p "${MODULE_DIR}"
mkdir -p "${TEMP_DIR}"

# Function to download from GitHub
download_module() {
    echo "📥 Downloading module from GitHub..."
    
    # Clone the repository
    if command -v git &> /dev/null; then
        echo "Using git to clone repository..."
        git clone "https://github.com/${GITHUB_REPO}.git" "${TEMP_DIR}"
    else
        echo "Git not found, downloading as ZIP..."
        curl -L "https://github.com/${GITHUB_REPO}/archive/main.zip" -o "${TEMP_DIR}/module.zip"
        cd "${TEMP_DIR}"
        unzip module.zip
        mv iris-velociraptorartifact-module-main/* .
        rm module.zip
        cd -
    fi
}

# Function to install module files
install_module() {
    echo "📦 Installing module files..."
    
    # Copy module files
    if [ -d "${TEMP_DIR}" ]; then
        cp -r "${TEMP_DIR}"/* "${MODULE_DIR}/"
        
        # Create __init__.py if it doesn't exist
        touch "${MODULE_DIR}/__init__.py"
        
        # Set permissions
        find "${MODULE_DIR}" -type f -name "*.py" -exec chmod 644 {} \;
        find "${MODULE_DIR}" -type d -exec chmod 755 {} \;
        
        echo "✅ Module files installed to ${MODULE_DIR}"
    else
        echo "❌ Error: Module source directory not found"
        exit 1
    fi
}

# Function to create configuration
create_config() {
    echo "⚙️  Creating module configuration..."
    
    cat > "${MODULE_DIR}/config.py" << 'EOF'
# IRIS Velociraptor Module Configuration

# Velociraptor Server Configuration
VELOCIRAPTOR_CONFIG = {
    'server_url': 'https://velociraptor-server:8889',
    'api_url': 'https://velociraptor-server:8001',
    'username': 'admin',
    'password': 'ChangeMe!',  # Should be set via environment variable
    'verify_ssl': False,
    'timeout': 30,
    'ca_cert_path': '/opt/iris/certs/ca.crt',
    'client_cert_path': '/opt/iris/certs/iris-velociraptor.crt',
    'client_key_path': '/opt/iris/certs/iris-velociraptor.key'
}

# Module Settings
MODULE_CONFIG = {
    'auto_sync': True,
    'sync_interval': 300,  # 5 minutes
    'max_results': 1000,
    'enable_webhooks': True,
    'webhook_secret': 'your-webhook-secret-here'
}

# Artifact Mapping
ARTIFACT_MAPPING = {
    'Windows.System.Services': {
        'iris_type': 'service',
        'description': 'Windows Services Information'
    },
    'Windows.Registry.NTUser': {
        'iris_type': 'registry',
        'description': 'NT User Registry Information'
    },
    'Generic.Client.Info': {
        'iris_type': 'system_info',
        'description': 'Client System Information'
    },
    'Windows.EventLogs.Evtx': {
        'iris_type': 'event_log',
        'description': 'Windows Event Logs'
    },
    'Linux.Sys.Crontab': {
        'iris_type': 'scheduled_task',
        'description': 'Linux Crontab Information'
    }
}

# Hunt Templates
HUNT_TEMPLATES = {
    'basic_triage': {
        'name': 'Basic Triage Collection',
        'artifacts': [
            'Generic.Client.Info',
            'Windows.System.Services',
            'Windows.Registry.NTUser',
            'Linux.Sys.Crontab'
        ],
        'description': 'Basic system triage collection'
    },
    'malware_hunt': {
        'name': 'Malware Detection Hunt',
        'artifacts': [
            'Windows.Detection.Yara.Process',
            'Windows.System.Pslist',
            'Windows.Network.Netstat'
        ],
        'description': 'Hunt for potential malware indicators'
    }
}
EOF

    echo "✅ Module configuration created"
}

# Function to create integration hooks
create_hooks() {
    echo "🔗 Creating integration hooks..."
    
    mkdir -p "${MODULE_DIR}/hooks"
    
    cat > "${MODULE_DIR}/hooks/__init__.py" << 'EOF'
# IRIS Velociraptor Integration Hooks
EOF

    cat > "${MODULE_DIR}/hooks/case_hooks.py" << 'EOF'
# Case Management Hooks for Velociraptor Integration

import logging
from typing import Dict, Any, Optional
from datetime import datetime

logger = logging.getLogger(__name__)

class VelociraptorCaseHooks:
    """Hooks for integrating Velociraptor with IRIS case management"""
    
    def __init__(self, velociraptor_client):
        self.velociraptor = velociraptor_client
    
    def on_case_created(self, case_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Called when a new case is created in IRIS"""
        try:
            logger.info(f"New case created: {case_data.get('case_name')}")
            
            # Create corresponding hunt in Velociraptor if needed
            if case_data.get('auto_hunt', False):
                hunt_result = self.create_case_hunt(case_data)
                return {'velociraptor_hunt_id': hunt_result.get('hunt_id')}
                
        except Exception as e:
            logger.error(f"Error in on_case_created hook: {e}")
        
        return None
    
    def on_case_updated(self, case_data: Dict[str, Any]) -> None:
        """Called when a case is updated in IRIS"""
        try:
            logger.info(f"Case updated: {case_data.get('case_name')}")
            
            # Update related hunts or flows if needed
            
        except Exception as e:
            logger.error(f"Error in on_case_updated hook: {e}")
    
    def create_case_hunt(self, case_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a Velociraptor hunt for the case"""
        hunt_config = {
            'name': f"IRIS Case: {case_data.get('case_name')}",
            'description': f"Automated hunt for case {case_data.get('case_id')}",
            'artifacts': case_data.get('hunt_artifacts', ['Generic.Client.Info']),
            'expires': (datetime.now().timestamp() + 86400 * 7) * 1000000  # 7 days
        }
        
        # Create hunt via Velociraptor API
        result = self.velociraptor.create_hunt(hunt_config)
        
        logger.info(f"Created hunt {result.get('hunt_id')} for case {case_data.get('case_id')}")
        return result
EOF

    cat > "${MODULE_DIR}/hooks/artifact_hooks.py" << 'EOF'
# Artifact Processing Hooks for Velociraptor Integration

import logging
from typing import Dict, Any, List
import json

logger = logging.getLogger(__name__)

class VelociraptorArtifactHooks:
    """Hooks for processing Velociraptor artifacts in IRIS"""
    
    def __init__(self, iris_client):
        self.iris = iris_client
    
    def process_artifact(self, artifact_data: Dict[str, Any]) -> Dict[str, Any]:
        """Process a Velociraptor artifact for IRIS"""
        try:
            artifact_name = artifact_data.get('artifact_name', '')
            
            # Route artifact based on type
            if 'Windows.System.Services' in artifact_name:
                return self.process_services_artifact(artifact_data)
            elif 'Windows.Registry' in artifact_name:
                return self.process_registry_artifact(artifact_data)
            elif 'Windows.EventLogs' in artifact_name:
                return self.process_eventlog_artifact(artifact_data)
            else:
                return self.process_generic_artifact(artifact_data)
                
        except Exception as e:
            logger.error(f"Error processing artifact: {e}")
            return {'status': 'error', 'message': str(e)}
    
    def process_services_artifact(self, artifact_data: Dict[str, Any]) -> Dict[str, Any]:
        """Process Windows Services artifact"""
        services = []
        
        for row in artifact_data.get('rows', []):
            service = {
                'name': row.get('Name', ''),
                'display_name': row.get('DisplayName', ''),
                'status': row.get('Status', ''),
                'start_type': row.get('StartType', ''),
                'path': row.get('PathName', ''),
                'description': row.get('Description', '')
            }
            services.append(service)
        
        return {
            'type': 'windows_services',
            'data': services,
            'count': len(services)
        }
    
    def process_registry_artifact(self, artifact_data: Dict[str, Any]) -> Dict[str, Any]:
        """Process Windows Registry artifact"""
        registry_entries = []
        
        for row in artifact_data.get('rows', []):
            entry = {
                'key': row.get('Key', ''),
                'value_name': row.get('ValueName', ''),
                'value_data': row.get('ValueData', ''),
                'value_type': row.get('ValueType', ''),
                'last_modified': row.get('LastModified', '')
            }
            registry_entries.append(entry)
        
        return {
            'type': 'registry_entries',
            'data': registry_entries,
            'count': len(registry_entries)
        }
    
    def process_eventlog_artifact(self, artifact_data: Dict[str, Any]) -> Dict[str, Any]:
        """Process Windows Event Log artifact"""
        events = []
        
        for row in artifact_data.get('rows', []):
            event = {
                'event_id': row.get('EventID', ''),
                'level': row.get('Level', ''),
                'source': row.get('Source', ''),
                'message': row.get('Message', ''),
                'timestamp': row.get('TimeCreated', ''),
                'computer': row.get('Computer', '')
            }
            events.append(event)
        
        return {
            'type': 'event_logs',
            'data': events,
            'count': len(events)
        }
    
    def process_generic_artifact(self, artifact_data: Dict[str, Any]) -> Dict[str, Any]:
        """Process generic artifact"""
        return {
            'type': 'generic',
            'artifact_name': artifact_data.get('artifact_name', ''),
            'data': artifact_data.get('rows', []),
            'count': len(artifact_data.get('rows', []))
        }
EOF

    echo "✅ Integration hooks created"
}

# Function to create setup script
create_setup() {
    echo "📋 Creating setup script..."
    
    cat > "${MODULE_DIR}/setup.py" << 'EOF'
#!/usr/bin/env python3
# IRIS Velociraptor Module Setup

import os
import sys
import json
import logging
from pathlib import Path

# Add module to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def setup_module():
    """Setup the IRIS Velociraptor module"""
    print("🔧 Setting up IRIS Velociraptor Module...")
    
    # Create required directories
    directories = [
        'logs',
        'temp',
        'artifacts',
        'exports'
    ]
    
    for directory in directories:
        Path(directory).mkdir(exist_ok=True)
        print(f"✅ Created directory: {directory}")
    
    # Create module info file
    module_info = {
        'name': 'iris-velociraptor',
        'version': '1.0.0',
        'description': 'IRIS integration module for Velociraptor',
        'author': 'DFIR Team',
        'dependencies': [
            'requests',
            'urllib3',
            'python-dateutil'
        ],
        'endpoints': [
            '/api/v1/velociraptor/clients',
            '/api/v1/velociraptor/hunts',
            '/api/v1/velociraptor/flows',
            '/api/v1/velociraptor/artifacts'
        ]
    }
    
    with open('module_info.json', 'w') as f:
        json.dump(module_info, f, indent=2)
    
    print("✅ Module info created")
    
    # Set up logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler('logs/velociraptor-module.log'),
            logging.StreamHandler()
        ]
    )
    
    print("🎉 IRIS Velociraptor Module setup completed!")
    print("📁 Module installed in:", os.path.dirname(os.path.abspath(__file__)))

if __name__ == '__main__':
    setup_module()
EOF

    chmod +x "${MODULE_DIR}/setup.py"
    echo "✅ Setup script created"
}

# Main execution
main() {
    echo "🎯 Starting IRIS Velociraptor Module installation..."
    
    # Download module
    download_module
    
    # Install module
    install_module
    
    # Create configuration
    create_config
    
    # Create hooks
    create_hooks
    
    # Create setup script
    create_setup
    
    # Run setup
    cd "${MODULE_DIR}"
    python3 setup.py
    cd -
    
    # Cleanup
    rm -rf "${TEMP_DIR}"
    
    echo "🎉 IRIS Velociraptor Module installation completed!"
    echo "📁 Module installed in: ${MODULE_DIR}"
    echo "⚙️  Configuration file: ${MODULE_DIR}/config.py"
    echo "📚 Next steps:"
    echo "   1. Update the configuration in ${MODULE_DIR}/config.py"
    echo "   2. Restart IRIS to load the new module"
    echo "   3. Configure Velociraptor connection in IRIS admin panel"
}

# Run main function
main