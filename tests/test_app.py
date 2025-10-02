"""
Basic tests for CBIT-AiStudio application
"""
import pytest
import sys
import os
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))


class TestApplicationImport:
    """Test application import and basic functionality"""
    
    def test_app_import(self):
        """Test that the main application can be imported"""
        try:
            from app_local import app
            assert app is not None
            assert app.config is not None
        except ImportError as e:
            pytest.fail(f"Failed to import app_local: {e}")
    
    def test_app_config(self):
        """Test application configuration"""
        from app_local import app
        
        # Check required config keys
        assert 'SECRET_KEY' in app.config
        assert 'MAX_CONTENT_LENGTH' in app.config
        assert 'SQLALCHEMY_DATABASE_URI' in app.config
    
    def test_routes_exist(self):
        """Test that main routes are registered"""
        from app_local import app
        
        # Get all registered routes
        routes = [rule.rule for rule in app.url_map.iter_rules()]
        
        # Check essential routes exist
        assert '/' in routes
        assert '/health' in routes
        assert '/api/generate' in routes
        assert '/api/result' in routes


class TestConfiguration:
    """Test configuration files and settings"""
    
    def test_config_file_exists(self):
        """Test that configuration file exists"""
        config_file = project_root / 'config_local.env'
        assert config_file.exists(), "config_local.env file should exist"
    
    def test_requirements_file_exists(self):
        """Test that requirements file exists"""
        requirements_file = project_root / 'requirements.txt'
        assert requirements_file.exists(), "requirements.txt file should exist"
    
    def test_dockerfile_exists(self):
        """Test that Dockerfile exists"""
        dockerfile = project_root / 'Dockerfile'
        assert dockerfile.exists(), "Dockerfile should exist"
    
    def test_docker_compose_exists(self):
        """Test that docker-compose.yml exists"""
        compose_file = project_root / 'docker-compose.yml'
        assert compose_file.exists(), "docker-compose.yml should exist"


class TestDirectoryStructure:
    """Test project directory structure"""
    
    def test_required_directories(self):
        """Test that required directories exist"""
        required_dirs = [
            'templates',
            'static',
            'instance',
            'downloads',
            'static/uploads'
        ]
        
        for dir_name in required_dirs:
            dir_path = project_root / dir_name
            assert dir_path.exists(), f"Directory {dir_name} should exist"
    
    def test_template_files(self):
        """Test that template files exist"""
        templates_dir = project_root / 'templates'
        index_template = templates_dir / 'index.html'
        assert index_template.exists(), "index.html template should exist"


class TestHealthCheck:
    """Test health check functionality"""
    
    def test_health_endpoint_structure(self):
        """Test health endpoint returns proper structure"""
        from app_local import app
        
        with app.test_client() as client:
            response = client.get('/health')
            assert response.status_code == 200
            
            data = response.get_json()
            assert 'status' in data
            assert 'local' in data
            assert 'server' in data
            assert 'timestamp' in data


if __name__ == '__main__':
    pytest.main([__file__])
