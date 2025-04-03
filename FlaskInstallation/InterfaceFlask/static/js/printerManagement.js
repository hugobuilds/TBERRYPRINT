let currentPrinterMenu = null;
let printerToDeleteName = null;

function showPrinterMenu(printerName) {
    const menu = document.getElementById(`printerMenu_${printerName}`);
    
    // Fermer le menu précédent s'il existe
    if (currentPrinterMenu && currentPrinterMenu !== menu) {
        currentPrinterMenu.classList.remove('show');
    }
    
    menu.classList.toggle('show');
    currentPrinterMenu = menu;
    
    // Fermer le menu si on clique ailleurs
    document.addEventListener('click', function closeMenu(e) {
        if (!e.target.closest('.printer-actions')) {
            menu.classList.remove('show');
            document.removeEventListener('click', closeMenu);
        }
    });
}

function showDeletePrinterModal(printerName) {
    printerToDeleteName = printerName;
    document.getElementById('printerToDelete').textContent = printerName;
    showModal('deletePrinterModal');
    
    // Fermer le menu contextuel
    if (currentPrinterMenu) {
        currentPrinterMenu.classList.remove('show');
    }
}

function deletePrinter() {
    if (!printerToDeleteName) return;
    
    fetch(`/delete_printer/${printerToDeleteName}`, {
        method: 'POST'
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            location.reload(); // Recharger la page pour mettre à jour la liste des imprimantes
        } else {
            alert('Erreur lors de la suppression de l\'imprimante: ' + data.message);
        }
    })
    .catch(error => {
        console.error('Error:', error);
        alert('Erreur lors de la suppression de l\'imprimante');
    })
    .finally(() => {
        hideModal('deletePrinterModal');
        printerToDeleteName = null;
    });
}

// Fonction de test d'impression
function testPrinter(printerName) {
    // Fermer le menu contextuel
    if (currentPrinterMenu) {
        currentPrinterMenu.classList.remove('show');
    }
    
    fetch(`/test_print/${printerName}`, {
        method: 'POST'
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            alert('Test d\'impression lancé avec succès');
        } else {
            alert('Erreur lors du test d\'impression: ' + data.message);
        }
    })
    .catch(error => {
        console.error('Error:', error);
        alert('Erreur lors du test d\'impression');
    });
}

// Fonction de mise à jour des imprimantes
function updatePrinterStatus(printers) {
    const container = document.getElementById('printers-container');
    
    if (printers.length === 0) {
        container.innerHTML = `
            <div class="printer-status">
                <i class="fas fa-times-circle"></i>
                <div class="stat-label">Aucune imprimante détectée</div>
            </div>
        `;
        return;
    }
    
    container.innerHTML = printers.map(printer => `
        <div class="printer-status">
            <div class="printer-header">
                <i class="${printer.status_icon.class}" style="color: ${printer.status_icon.color}"></i>
                <div>
                    <div class="stat-value">${printer.name}</div>
                    <div class="stat-label">${printer.status_text}</div>
                </div>
                <div class="printer-actions">
                    <button onclick="showPrinterMenu('${printer.name}')" class="btn-icon">
                        <i class="fa-solid fa-ellipsis-vertical"></i>
                    </button>
                    <div id="printerMenu_${printer.name}" class="printer-menu">
                        <button onclick="testPrinter('${printer.name}')" class="printer-menu-item">
                            <i class="fas fa-print"></i>
                            Test d'impression
                        </button>
                        <button onclick="showDeletePrinterModal('${printer.name}')" class="printer-menu-item">
                            <i class="fas fa-trash"></i>
                            Supprimer
                        </button>
                    </div>
                </div>
            </div>
        </div>
    `).join('');
}