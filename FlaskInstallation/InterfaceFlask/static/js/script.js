// Fonction pour mettre à jour les statistiques
function updateStats() {
    fetch('/stats')
        .then(response => {
            if (!response.ok) {
                throw new Error('Network response was not ok');
            }
            return response.json();
        })
        .then(data => {
            // Mise à jour CPU et RAM existante
            document.querySelector('.stat-value[data-stat="temperature"]').textContent = data.temperature;
            document.querySelector('.stat-value[data-stat="cpu_percent"]').textContent = data.cpu_percent;
            document.querySelector('.stat-value[data-stat="ram_used"]').textContent = data.ram_used;
            document.querySelector('.stat-value[data-stat="ram_percent"]').textContent = data.ram_percent;
            
            // Mise à jour des imprimantes
            updatePrinterStatus(data.printers);
        })
        .catch(error => {
            console.error('Error fetching stats:', error);
        });
}

// Mise à jour les stats toutes les 5 secondes
setInterval(updateStats, 5000);