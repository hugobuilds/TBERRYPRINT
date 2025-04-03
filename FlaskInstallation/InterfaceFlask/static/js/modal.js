// Gestionnaire pour la touche Échap
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        const modals = ['rebootModal', 'hostnameModal', 'updateModal'];
        modals.forEach(id => {
            if (document.getElementById(id).style.display === 'block') {
                hideModal(id);
            }
        });
    }
});

// Gestionnaires d'événements pour fermer les modals
document.querySelectorAll('.modal-overlay').forEach(modal => {
    modal.addEventListener('click', function(e) {
        if (e.target === this) {
            hideModal(this.id);
        }
    });
});


function showModal(elementId) {
    const modal = document.getElementById(elementId);
    modal.style.display = 'block';
    setTimeout(() => {
        modal.querySelector('.modal').classList.add('show');
    }, 10);
}

function hideModal(elementId) {
    const modal = document.getElementById(elementId);
    modal.querySelector('.modal').classList.remove('show');
    setTimeout(() => {
        modal.style.display = 'none';
    }, 300);
}

function submitHostnameForm() {
    const form = document.getElementById('hostnameForm');
    const input = form.querySelector('input[name="hostname"]');
    
    if (input.value.trim() === '') {
        alert('Veuillez entrer un hostname valide');
        return;
    }
    
    if (!input.checkValidity()) {
        alert('Le hostname ne doit contenir que des lettres, chiffres et tirets');
        return;
    }
    
    form.submit();
}


// Fonction pour configurer le Wi-Fi
function setupWifi() {
    const ssid = document.getElementById('ssid').value.trim();
    const password = document.getElementById('password').value.trim();
    
    if (!ssid) {
        alert('Veuillez entrer le nom du réseau (SSID)');
        return;
    }
    
    if (!password) {
        alert('Veuillez entrer le mot de passe');
        return;
    }
    
    // Création de FormData pour l'envoi
    const formData = new FormData();
    formData.append('ssid', ssid);
    formData.append('password', password);
    
    // Afficher un message d'attente
    document.querySelector('#wifiModal .modal-content').innerHTML = `
        <p>Configuration du Wi-Fi en cours...</p>
        <p>Veuillez patienter, cette opération peut prendre quelques instants.</p>
        <div style="text-align: center; margin: 2rem 0;">
            <i class="fas fa-spinner fa-spin" style="font-size: 2rem; color: var(--primary);"></i>
        </div>
    `;
    
    // Désactiver les boutons pendant le traitement
    const buttons = document.querySelectorAll('#wifiModal .modal-actions button');
    buttons.forEach(button => {
        button.disabled = true;
        button.style.opacity = 0.5;
    });
    
    // Envoyer la requête
    fetch('/setup_wifi', {
        method: 'POST',
        body: formData
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            document.querySelector('#wifiModal .modal-content').innerHTML = `
                <p>Configuration Wi-Fi réussie !</p>
                <p>Le Raspberry Pi est maintenant connecté au réseau "${ssid}".</p>
                <div style="text-align: center; margin: 2rem 0;">
                    <i class="fas fa-check-circle" style="font-size: 2rem; color: var(--primary);"></i>
                </div>
            `;
            
            // Réactiver uniquement le bouton Fermer
            buttons[0].disabled = false;
            buttons[0].style.opacity = 1;
            buttons[0].textContent = 'Fermer';
            
            // Cacher le bouton Connecter
            buttons[1].style.display = 'none';
        } else {
            document.querySelector('#wifiModal .modal-content').innerHTML = `
                <p>Erreur lors de la configuration Wi-Fi :</p>
                <p>${data.message}</p>
                <div style="text-align: center; margin: 2rem 0;">
                    <i class="fas fa-exclamation-circle" style="font-size: 2rem; color: var(--danger);"></i>
                </div>
                <p>Veuillez réessayer avec les bonnes informations.</p>
            `;
            
            // Réactiver les boutons
            buttons.forEach(button => {
                button.disabled = false;
                button.style.opacity = 1;
            });
            buttons[1].textContent = 'Réessayer';
            buttons[1].onclick = function() {
                hideModal('wifiModal');
                setTimeout(() => {
                    showModal('wifiModal');
                }, 300);
            };
        }
    })
    .catch(error => {
        console.error('Error:', error);
        document.querySelector('#wifiModal .modal-content').innerHTML = `
            <p>Erreur lors de la communication avec le serveur :</p>
            <p>${error.message || 'Erreur inconnue'}</p>
            <div style="text-align: center; margin: 2rem 0;">
                <i class="fas fa-exclamation-triangle" style="font-size: 2rem; color: var(--danger);"></i>
            </div>
        `;
        
        // Réactiver les boutons
        buttons.forEach(button => {
            button.disabled = false;
            button.style.opacity = 1;
        });
    });
}