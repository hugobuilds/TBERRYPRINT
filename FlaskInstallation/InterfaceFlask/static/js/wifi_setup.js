// ===== CONSTANTES ET UTILITAIRES ===== \\

const API_ENDPOINTS = {
    WIFI_NETWORKS: '/api/wifi_networks',
    SETUP_WIFI: '/setup_wifi',
    SETUP_WIFI_CONNECTED: '/setup_wifi_connected'
};

const DOM_IDS = {
    REFRESH_BTN: 'refreshBtn',
    NETWORKS_LIST: 'networksList',
    WIFI_STATUS: 'wifiStatus',
    SELECTED_SSID: 'selectedSsid',
    SELECTED_NETWORK_NAME: 'selectedNetworkName',
    NETWORK_PASSWORD: 'networkPassword',
    WIFI_PASSWORD_MODAL: 'wifiPasswordModal',
    WIFI_CONFIRMATION_MODAL: 'wifiConfirmationModal'
};

const MODAL_SELECTORS = {
    CONTENT: '.modal-content',
    ACTIONS: '.modal-actions button'
};


// ===== TEMPLATES HTML ===== \\

const TEMPLATES = {
    LOADING: `
        <div class="loading-spinner">
            <i class="fas fa-spinner fa-spin fa-2x"></i>
        </div>
    `,
    NO_NETWORKS: `
        <div class="network-error">
            <i class="fas fa-wifi" style="color: #95a5a6;"></i>
            <p>Aucun réseau Wi-Fi détecté</p>
            <p>Nous avons détecté aucun réseau Wi-Fi à proximité</p>
        </div>
    `,
    NETWORK_ERROR: `
        <div class="network-error">
            <i class="fas fa-exclamation-triangle fa-2x"></i>
            <p>Erreur lors de la récupération des réseaux Wi-Fi</p>
            <p>Veuillez réessayer ou vérifier les permissions système</p>
        </div>
    `,
    CONNECTING: `
        <p>Vérification de la connexion Wi-Fi en cours...</p>
        <p>Veuillez patienter, cette opération peut prendre quelques instants.</p>
        <div style="text-align: center; margin: 2rem 0;">
            <i class="fas fa-spinner fa-spin" style="font-size: 2rem; color: var(--primary);"></i>
        </div>
    `,
    CONNECTED_STATUS: (status) => `
        <div class="current-connection">
            <h3><i class="fas fa-check-circle" style="color: #2ecc71;"></i> Connecté</h3>
            <div class="stat">
                <span class="stat-label">Réseau:</span>
                <span class="stat-value">${status.ssid}</span>
            </div>
            <div class="stat">
                <span class="stat-label">Adresse IP:</span>
                <span class="stat-value">${status.ip_address}</span>
            </div>
        </div>
    `,
    NOT_CONNECTED_STATUS: `
        <div class="stat" style="margin-bottom: 1.5rem;">
            <i class="fas fa-times-circle" style="color: #e74c3c;"></i>
            <span class="stat-value">Non connecté à un réseau Wi-Fi</span>
        </div>
    `,
    CONNECTION_ERROR: (ssid, errorMessage) => `
        <div class="connection-error">
            <i class="fas fa-exclamation-triangle" style="color: #e74c3c; font-size: 2rem; margin-bottom: 1rem;"></i>
            <p style="color: #e74c3c; font-weight: bold;">Échec de connexion</p>
            <p>${errorMessage}</p>
            <p style="margin-top: 1rem;">Veuillez vérifier le mot de passe et réessayer.</p>
            
            <div style="margin-top: 1.5rem;">
                <input type="hidden" id="${DOM_IDS.SELECTED_SSID}" value="${ssid}">
                <input type="password" 
                    id="${DOM_IDS.NETWORK_PASSWORD}"
                    name="password" 
                    class="form-control" 
                    style="width: 100%; 
                          padding: 0.75rem;
                          background: rgba(255, 255, 255, 0.1);
                          border: 1px solid rgba(255, 255, 255, 0.2);
                          border-radius: 0.5rem;
                          color: var(--text);
                          font-size: 1rem;"
                    required
                    placeholder="Mot de passe">
            </div>
        </div>
    `
};


// ===== FONCTIONS UTILITAIRES ===== \\
function getElement(id) {
    return document.getElementById(id);
}

function setElementHTML(id, html) {
    getElement(id).innerHTML = html;
}

function getSignalStrengthClass(signalPercent) {
    // Utilise toujours la même classe pour l'instant (à modifier si achat des icones)
    return 'fa-solid fa-wifi';
}

function toggleLoadingButtons(modalId, isLoading) {
    const buttons = document.querySelectorAll(`#${modalId} ${MODAL_SELECTORS.ACTIONS}`);
    buttons.forEach(button => {
        button.disabled = isLoading;
        button.style.opacity = isLoading ? 0.5 : 1;
    });
}


// ===== FONCTIONS PRINCIPALES ===== \\

function fetchWifiNetworks() {
    const refreshBtn = getElement(DOM_IDS.REFRESH_BTN);
    
    // Afficher l'icône de chargement
    refreshBtn.classList.add('spinning');
    setElementHTML(DOM_IDS.NETWORKS_LIST, TEMPLATES.LOADING);
    
    // Récupérer les réseaux depuis l'API
    fetch(API_ENDPOINTS.WIFI_NETWORKS)
        .then(response => {
            if (!response.ok) {
                throw new Error('Network response was not ok');
            }
            return response.json();
        })
        .then(data => {
            // Mettre à jour le statut de connexion actuel
            updateConnectionStatus(data.current_status);
            
            // Afficher les réseaux disponibles
            displayWifiNetworks(data.networks, data.current_status.ssid);
        })
        .catch(error => {
            console.error('Error fetching Wi-Fi networks:', error);
            setElementHTML(DOM_IDS.NETWORKS_LIST, TEMPLATES.NETWORK_ERROR);
        })
        .finally(() => {
            // Arrêter l'animation de rotation
            refreshBtn.classList.remove('spinning');
        });
}

function updateConnectionStatus(status) {
    const wifiStatus = getElement(DOM_IDS.WIFI_STATUS);
    const statusHTML = status.connected 
        ? TEMPLATES.CONNECTED_STATUS(status)
        : TEMPLATES.NOT_CONNECTED_STATUS;
    
    // Mise à jour de l'état de connexion
    wifiStatus.innerHTML = statusHTML;
}

function displayWifiNetworks(networks, currentSsid) {
    if (networks.length === 0) {
        setElementHTML(DOM_IDS.NETWORKS_LIST, TEMPLATES.NO_NETWORKS);
        return;
    }
    
    // Générer le HTML pour chaque réseau
    const networksHTML = networks.map(network => {
        const isCurrentNetwork = network.ssid === currentSsid;
        const signalClass = getSignalStrengthClass(network.signal_percent);
        const hasConnected = network.hasConnected;
        // Pour le cadena (si wifi crypté ou non)
        const lockIcon = network.encrypted ? '<i class="fas fa-lock" style="margin-left: 0.5rem; color: #95a5a6;"></i>' : '';
        // Définir un style vert pour l'icône si c'est le réseau courant
        const iconStyle = isCurrentNetwork ? 'color: #2ecc71;' : '';
    
        return `
            <div class="wifi-network ${isCurrentNetwork ? 'current-connection' : ''}" 
                 onclick="selectNetwork('${network.ssid.replace(/'/g, "\\'")}', ${hasConnected})" 
                 data-encrypted="${network.encrypted}">
                <div class="wifi-icon">
                    <i class="${signalClass}" style="${iconStyle}"></i>
                </div>
                <div class="wifi-info">
                    <div class="wifi-name">
                        ${network.ssid} ${lockIcon}
                        ${isCurrentNetwork ? '<span style="color: #2ecc71; margin-left: 0.5rem;">(Connecté)</span>' : ''}
                    </div>
                    <div class="wifi-details">
                        Signal: ${network.signal_level} dBm
                    </div>
                </div>

                <div class="wifi-signal">
                    <div class="progress-bar">
                        <div class="progress-fill" style="width: ${network.signal_percent}%;"></div>
                    </div>
                </div>
            </div>
        `;
    }).join('');    
    
    setElementHTML(DOM_IDS.NETWORKS_LIST, networksHTML);
}

function selectNetwork(ssid, hasConnected) {
    getElement(DOM_IDS.SELECTED_SSID).value = ssid;
    getElement(DOM_IDS.SELECTED_NETWORK_NAME).textContent = ssid;
    getElement(DOM_IDS.NETWORK_PASSWORD).value = '';
    
    showModal(DOM_IDS.WIFI_PASSWORD_MODAL);
    
    if (hasConnected) {
        connectToWifi(ssid, null, true);
    }
}

function connectToNetwork() {
    const ssid = getElement(DOM_IDS.SELECTED_SSID).value;
    const password = getElement(DOM_IDS.NETWORK_PASSWORD).value;
    
    if (!password) {
        alert('Veuillez entrer un mot de passe');
        return;
    }
    
    connectToWifi(ssid, password, false);
}

function connectToWifi(ssid, password, isAlreadyConnected) {
    // Afficher l'écran de chargement
    document.querySelector(`#${DOM_IDS.WIFI_PASSWORD_MODAL} ${MODAL_SELECTORS.CONTENT}`).innerHTML = TEMPLATES.CONNECTING;
    
    // Désactiver les boutons pendant le traitement
    toggleLoadingButtons(DOM_IDS.WIFI_PASSWORD_MODAL, true);
    
    // Préparation des données
    const formData = new FormData();
    formData.append('ssid', ssid);
    if (password) formData.append('password', password);
    
    // Déterminer l'endpoint à utiliser
    const endpoint = isAlreadyConnected 
        ? API_ENDPOINTS.SETUP_WIFI_CONNECTED 
        : API_ENDPOINTS.SETUP_WIFI;
    
    // Envoyer la requête
    fetch(endpoint, {
        method: 'POST',
        body: formData
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            hideModal(DOM_IDS.WIFI_PASSWORD_MODAL);
            showModal(DOM_IDS.WIFI_CONFIRMATION_MODAL);
        } else {
            // Afficher un message d'erreur dans la modale
            document.querySelector(`#${DOM_IDS.WIFI_PASSWORD_MODAL} ${MODAL_SELECTORS.CONTENT}`).innerHTML = 
                TEMPLATES.CONNECTION_ERROR(ssid, data.message);
            
            // Réactiver les boutons
            toggleLoadingButtons(DOM_IDS.WIFI_PASSWORD_MODAL, false);
        }
    })
    .catch(error => {
        console.error('Error:', error);
        
        // Afficher un message d'erreur dans la modale
        document.querySelector(`#${DOM_IDS.WIFI_PASSWORD_MODAL} ${MODAL_SELECTORS.CONTENT}`).innerHTML = 
            TEMPLATES.CONNECTION_ERROR(ssid, error.message || 'Erreur inconnue');
        
        // Réactiver les boutons
        toggleLoadingButtons(DOM_IDS.WIFI_PASSWORD_MODAL, false);
    });
}


// ===== ÉVÉNEMENT AU CHARGEMENT DE LA PAGE ===== \\

document.addEventListener('DOMContentLoaded', function() {
    // Récupérer les réseaux dès le chargement
    fetchWifiNetworks();
    
    // Configurer le bouton d'actualisation
    getElement(DOM_IDS.REFRESH_BTN).addEventListener('click', fetchWifiNetworks);
});