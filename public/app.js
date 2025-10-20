// Global configuration
let currentConfig = {};

// Initialize application
document.addEventListener('DOMContentLoaded', async () => {
    await loadConfiguration();
    loadTemplates();
    updateEndpointURLs();
    
    // Set up event listeners
    document.getElementById('modeAuto').addEventListener('change', handleModeChange);
    document.getElementById('modeManual').addEventListener('change', handleModeChange);
    document.getElementById('modeLocal').addEventListener('change', handleModeChange);
});

// Tab switching
function showTab(tabName) {
    // Hide all tabs
    document.querySelectorAll('.tab-content').forEach(tab => {
        tab.classList.remove('active');
    });
    
    // Remove active class from all buttons
    document.querySelectorAll('.tab-button').forEach(button => {
        button.classList.remove('active');
    });
    
    // Show selected tab
    document.getElementById(tabName).classList.add('active');
    
    // Mark button as active
    event.target.classList.add('active');
}

// Handle configuration mode change
function handleModeChange() {
    const mode = document.querySelector('input[name="mode"]:checked').value;
    
    // Hide all config modes
    document.getElementById('autoConfig').style.display = 'none';
    document.getElementById('manualConfig').style.display = 'none';
    
    // Show selected mode
    if (mode === 'auto') {
        document.getElementById('autoConfig').style.display = 'block';
    } else if (mode === 'manual') {
        document.getElementById('manualConfig').style.display = 'block';
    }
}

// Load configuration from server
async function loadConfiguration() {
    try {
        const response = await fetch('/api/config');
        const data = await response.json();
        
        currentConfig = data.wpadConfig;
        
        // Update UI
        document.getElementById('wpadEnabled').checked = currentConfig.enabled;
        document.getElementById('domain').value = currentConfig.domain || '';
        document.getElementById('pacUrl').value = currentConfig.pacUrl || '';
        document.getElementById('pacEditor').value = data.currentPACScript || '';
        
        // Set mode
        if (currentConfig.autoDiscoveryMode === 'auto') {
            document.getElementById('modeAuto').checked = true;
        } else if (currentConfig.autoDiscoveryMode === 'manual') {
            document.getElementById('modeManual').checked = true;
        } else {
            document.getElementById('modeLocal').checked = true;
        }
        
        handleModeChange();
    } catch (error) {
        console.error('Error loading configuration:', error);
    }
}

// Save configuration
async function saveConfiguration() {
    const config = {
        enabled: document.getElementById('wpadEnabled').checked,
        domain: document.getElementById('domain').value,
        autoDiscoveryMode: document.querySelector('input[name="mode"]:checked').value,
        pacUrl: document.getElementById('pacUrl').value
    };
    
    try {
        const response = await fetch('/api/config', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ config })
        });
        
        if (response.ok) {
            showMessage('configMessage', 'Configuration saved successfully!', 'success');
        } else {
            showMessage('configMessage', 'Error saving configuration', 'error');
        }
    } catch (error) {
        showMessage('configMessage', 'Error: ' + error.message, 'error');
    }
}

// Validate PAC script
async function validatePACScript() {
    const script = document.getElementById('pacEditor').value;
    
    try {
        const response = await fetch('/api/validate-pac', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ script })
        });
        
        const result = await response.json();
        
        if (result.valid) {
            showMessage('editorMessage', 'Script is valid! Test result: ' + result.testResult.result, 'success');
        } else {
            showMessage('editorMessage', 'Validation error: ' + result.error, 'error');
        }
    } catch (error) {
        showMessage('editorMessage', 'Error: ' + error.message, 'error');
    }
}

// Save PAC script
async function savePACScript() {
    const script = document.getElementById('pacEditor').value;
    
    try {
        const response = await fetch('/api/config', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ pacScript: script })
        });
        
        if (response.ok) {
            showMessage('editorMessage', 'PAC script saved successfully!', 'success');
        } else {
            showMessage('editorMessage', 'Error saving PAC script', 'error');
        }
    } catch (error) {
        showMessage('editorMessage', 'Error: ' + error.message, 'error');
    }
}

// Format PAC script
function formatPACScript() {
    const editor = document.getElementById('pacEditor');
    try {
        // Simple formatting - not perfect but helpful
        let script = editor.value;
        script = script.replace(/\{/g, ' {\n    ');
        script = script.replace(/\}/g, '\n}');
        script = script.replace(/;/g, ';\n    ');
        editor.value = script;
    } catch (error) {
        showMessage('editorMessage', 'Error formatting script', 'error');
    }
}

// Fetch remote PAC file
async function fetchPACFile() {
    const url = document.getElementById('pacUrl').value;
    
    if (!url) {
        showMessage('configMessage', 'Please enter a PAC file URL', 'error');
        return;
    }
    
    try {
        const response = await fetch('/api/fetch-pac', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ url })
        });
        
        const result = await response.json();
        
        if (result.success) {
            document.getElementById('pacEditor').value = result.script;
            showMessage('configMessage', 'PAC file fetched successfully!', 'success');
            // Switch to editor tab
            showTab('editor');
            document.querySelectorAll('.tab-button')[1].classList.add('active');
            document.querySelectorAll('.tab-button')[0].classList.remove('active');
        } else {
            showMessage('configMessage', 'Error fetching PAC file: ' + result.error, 'error');
        }
    } catch (error) {
        showMessage('configMessage', 'Error: ' + error.message, 'error');
    }
}

// Test proxy rules
async function testProxyRules() {
    const url = document.getElementById('testUrl').value;
    
    if (!url) {
        alert('Please enter a URL to test');
        return;
    }
    
    try {
        const response = await fetch('/api/test-url', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ url })
        });
        
        const result = await response.json();
        const resultsDiv = document.getElementById('testResults');
        
        if (result.success) {
            resultsDiv.innerHTML = `
                <div class="result-item">
                    <strong>Test URL:</strong>
                    <div class="result-value">${result.proxyInfo.url}</div>
                    <strong>Result:</strong>
                    <div class="result-value">${result.proxyInfo.result}</div>
                    <strong>Description:</strong>
                    <div>${result.proxyInfo.description}</div>
                </div>
            `;
        } else {
            resultsDiv.innerHTML = `
                <div class="result-item" style="border-color: #dc3545;">
                    <strong>Error:</strong> ${result.error}
                </div>
            `;
        }
        
        resultsDiv.classList.add('show');
    } catch (error) {
        alert('Error testing URL: ' + error.message);
    }
}

// Quick test function
function quickTest(url) {
    document.getElementById('testUrl').value = url;
    testProxyRules();
}

// Load PAC templates
async function loadTemplates() {
    try {
        const response = await fetch('/api/templates');
        const templates = await response.json();
        
        const templateList = document.getElementById('templateList');
        templateList.innerHTML = '';
        
        templates.forEach(template => {
            const card = document.createElement('div');
            card.className = 'template-card';
            card.innerHTML = `
                <h3>${template.name}</h3>
                <p>${template.description}</p>
                <pre>${template.script}</pre>
                <button onclick="useTemplate('${encodeURIComponent(template.script)}')">Use This Template</button>
            `;
            templateList.appendChild(card);
        });
    } catch (error) {
        console.error('Error loading templates:', error);
    }
}

// Use template
function useTemplate(encodedScript) {
    const script = decodeURIComponent(encodedScript);
    document.getElementById('pacEditor').value = script;
    
    // Switch to editor tab
    showTab('editor');
    document.querySelectorAll('.tab-button')[1].classList.add('active');
    document.querySelectorAll('.tab-button')[3].classList.remove('active');
}

// Update endpoint URLs
function updateEndpointURLs() {
    const baseUrl = window.location.origin;
    document.getElementById('wpadUrl').textContent = `${baseUrl}/wpad.dat`;
    document.getElementById('pacFileUrl').textContent = `${baseUrl}/proxy.pac`;
}

// Copy to clipboard
function copyToClipboard(elementId) {
    const text = document.getElementById(elementId).textContent;
    navigator.clipboard.writeText(text).then(() => {
        alert('URL copied to clipboard!');
    }).catch(err => {
        console.error('Error copying to clipboard:', err);
    });
}

// Show message
function showMessage(elementId, message, type) {
    const messageDiv = document.getElementById(elementId);
    messageDiv.textContent = message;
    messageDiv.className = `message ${type}`;
    
    // Auto-hide after 5 seconds
    setTimeout(() => {
        messageDiv.className = 'message';
    }, 5000);
}