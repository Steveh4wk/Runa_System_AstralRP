/**
 * =============================================================================
 * Runa System - JavaScript Frontend
 * Author: Stefano Coding Corp. - Developed Script Runa_System 1.1.3
 * Version: 1.1.3
 * Description: stefanolucianocorp@gmail.com All Rights Reserved
 * =============================================================================
 */

// Selectors
let output = document.querySelector("#timer");
let craftingMenu = document.querySelector('#crafting-menu');
let upgradePhase2 = document.querySelector('#upgrade-phase2');
let runeSquares = document.querySelectorAll('.rune-square');
let selectedRuneDiv = document.querySelector('#selected-rune');
let selectedName = document.querySelector('#selected-name');
let confirmButton = document.querySelector('#confirm-button');
let closeButton = document.querySelector('#close-button');
let upgradeButton = document.querySelector('#upgrade-button');
let closePhase2Button = document.querySelector('#close-phase2-button');
let upgradeResultMessage = document.querySelector('#upgrade-result-message');

// Notification selectors
let upgradeNotification = document.querySelector('#upgrade-notification');
let notificationTitle = document.querySelector('#notification-title');
let notificationMessage = document.querySelector('#notification-message');
let closeNotificationButton = document.querySelector('#close-notification');

// Runes data - will be populated dynamically
let runes = [];

let selectedRune = null;

function showCraftingMenu() {
  // Show the body first
  document.querySelector("body").style = "display: block";
  
  // Hide timer display for crafting
  if (output) {
    output.style.display = "none";
  }
  
  craftingMenu.style.display = 'block';
  selectedRune = null;
  selectedRuneDiv.style.display = 'none';
  confirmButton.style.display = 'none';
  
  console.log('Crafting menu shown');
}

function hideCraftingMenu() {
   craftingMenu.style.display = 'none';

   // Hide the body
   document.querySelector("body").style = "display: none";

   // Stop any running timer
   stopCraftingTimer();

   // Hide timer display
   if (output) {
     output.style.display = 'none';
   }

   console.log('Crafting menu hidden');
}

function showUpgradePhase2(runeData) {
   // Hide crafting menu
   craftingMenu.style.display = 'none';

   // Show phase 2
   upgradePhase2.style.display = 'block';

   // Populate phase 2 data
   const stoneImage = document.getElementById('stone-image');
   const stoneName = document.getElementById('stone-name');
   const stoneLevel = document.getElementById('stone-level');
   const galeoniRequired = document.getElementById('galeoni-required');
   const nextLevelInfo = document.getElementById('next-level-info');
   const successChance = document.getElementById('success-chance');

   // Set stone info
   const runeConfig = {
     'runa_hp': { name: 'Vita', color: '#ff6b6b', image: 'nui://ox_inventory/web/images/runa_hp.png' },
     'runa_danno': { name: 'Danno', color: '#ffa500', image: 'nui://ox_inventory/web/images/runa_danno.png' },
     'runa_mp': { name: 'Mana', color: '#0066ff', image: 'nui://ox_inventory/web/images/runa_mp.png' },
     'runa_cdr': { name: 'Cooldown', color: '#00ff66', image: 'nui://ox_inventory/web/images/runa_cdr.png' },
     'runa_speed': { name: 'Velocità', color: '#ffff00', image: 'nui://ox_inventory/web/images/runa_speed.png' }
   };

   const baseType = runeData.type.replace(/_divina$/, '').replace(/_(\d+)$/, '');
   const runeInfo = runeConfig[baseType];
   const currentLevel = runeData.level || 0;
   const levelText = currentLevel === 5 ? ' (Divina)' : currentLevel === 0 ? '' : ' (+' + currentLevel + ')';

   stoneImage.innerHTML = `<img src="${runeInfo.image}" style="width: 60px; height: 60px; border-radius: 50%; box-shadow: 0 0 10px ${runeInfo.color};">`;
   stoneName.textContent = runeInfo.name + levelText;
   stoneLevel.textContent = 'Livello Attuale: ' + (currentLevel === 5 ? 'Divina' : currentLevel);

   // Set upgrade info
   galeoniRequired.textContent = 'Galeoni Richiesti: 200';

   const nextLevel = currentLevel + 1;
   const nextLevelText = nextLevel === 5 ? 'Divina' : '+' + nextLevel;
   nextLevelInfo.textContent = 'Prossimo Livello: ' + nextLevelText;

   // Calculate success chance
   const chances = { 0: 100, 1: 80, 2: 60, 3: 40, 4: 20 };
   const chance = chances[currentLevel] || 0;
   successChance.textContent = 'Probabilità di Successo: ' + chance + '%';

   // Hide result message
   upgradeResultMessage.style.display = 'none';

   console.log('Upgrade phase 2 shown for rune:', runeData.type);
}

function hideUpgradePhase2() {
   upgradePhase2.style.display = 'none';
   document.querySelector("body").style = "display: none";

   // Ensure focus is released by calling client callback
   fetch('https://Runa_System/closePhase2', {
     method: 'POST',
     headers: {
       'Content-Type': 'application/json; charset=UTF-8',
     },
     body: JSON.stringify({})
   }).catch(() => {
     console.log('JavaScript: closePhase2 request failed');
   });

   console.log('Upgrade phase 2 hidden');
}

function showUpgradeNotification(title, message) {
  notificationTitle.textContent = title;
  notificationMessage.textContent = message;
  upgradeNotification.style.display = 'block';
  document.querySelector("body").style = "display: block";
}

function hideUpgradeNotification() {
  upgradeNotification.style.display = 'none';
  document.querySelector("body").style = "display: none";
}

// Upgrade progress variables
let upgradeTimer = null;
let upgradeProgressTimer = null;
let safetyTimeout = null;
let currentUpgradeTime = 3;

// Safety timeout to force close after 6 seconds maximum (3s timer + 3s result)
function startSafetyTimeout() {
  // Clear any existing safety timeout
  if (safetyTimeout) {
    clearTimeout(safetyTimeout);
  }
  
  // Force close after 6 seconds from start (3s timer + 3s result display)
  safetyTimeout = setTimeout(() => {
    console.log('JavaScript: Safety timeout triggered - forcing window close');
    closeUpgradeProgress();
  }, 6000); // Ridotto da 10000 a 6000
}

// Upgrade progress functions
function showUpgradeProgress() {
  const progressWindow = document.getElementById('upgrade-progress');
  const craftingMenu = document.getElementById('crafting-menu');
  
  // Hide crafting menu and show progress
  if (craftingMenu) craftingMenu.style.display = 'none';
  if (progressWindow) {
    progressWindow.style.display = 'block';
    progressWindow.classList.remove('closing');
  }
  
  // Reset UI elements
  resetUpgradeUI();
  
  // Start safety timeout
  startSafetyTimeout();
  
  console.log('JavaScript: Showing upgrade progress window');
}

function resetUpgradeUI() {
  // Reset timer and messages
  currentUpgradeTime = 3; // Parte da 3, non da 5
  const timer = document.getElementById('upgrade-timer');
  const spinner = document.getElementById('upgrade-spinner');
  const result = document.getElementById('upgrade-result');
  const message = document.getElementById('upgrade-message');
  const title = document.getElementById('upgrade-title');
  
  if (timer) {
    timer.textContent = '3'; // Mostra 3 all'inizio
    timer.classList.remove('pulse');
  }
  if (spinner) spinner.style.display = 'block';
  if (result) {
    result.style.display = 'none';
    result.classList.remove('success', 'failure');
  }
  if (message) message.textContent = 'Stiamo canalizzando l\'antica magia...';
  if (title) title.textContent = 'Incantesimo in Corso...';
}

function startUpgradeTimer() {
  const timer = document.getElementById('upgrade-timer');
  const spinner = document.getElementById('upgrade-spinner');
  const message = document.getElementById('upgrade-message');
  
  currentUpgradeTime = 3; // Ridotto da 5 a 3 secondi
  
  upgradeTimer = setInterval(() => {
    currentUpgradeTime--;
    
    if (timer) {
      timer.textContent = currentUpgradeTime;
      // Add pulse effect on last second
      if (currentUpgradeTime === 1) {
        timer.classList.add('pulse');
      }
    }
    
    // Update message based on time
    if (currentUpgradeTime === 2 && message) {
      message.textContent = 'La magia si sta concentrando...';
    } else if (currentUpgradeTime === 1 && message) {
      message.textContent = 'Picco massimo potere!';
    }
    
    if (currentUpgradeTime <= 0) {
      clearInterval(upgradeTimer);
      upgradeTimer = null;

      // Hide timer but keep spinner for short buffering
      if (timer) timer.style.display = 'none';
      if (spinner) spinner.style.display = 'block';

      // Show extended buffering message
      if (message) {
        message.textContent = 'Finalizzazione dell\'incantesimo...';
      }

      console.log('JavaScript: Upgrade timer completed, sending upgrade request to server');

      // Invia la richiesta al server
      fetch('https://Runa_System/triggerUpgrade', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({ rune: selectedRune.key })
      }).catch(() => {
        // Silently fail if fetch doesn't work
        console.log('JavaScript: Upgrade request failed');
      });

      // Forza il banner di risultato dopo 1 secondo di buffering
      setTimeout(() => {
        const banner = document.getElementById('upgrade-banner');
        if (banner) {
          banner.style.display = 'block';
          banner.textContent = '⏳ Elaborazione in corso...';
          banner.style.color = '#ffd700';
          banner.style.background = 'rgba(255, 215, 0, 0.15)';
          banner.style.border = '2px solid #ffd700';
          banner.style.textShadow = '0 0 8px rgba(255, 215, 0, 0.5), -1px -1px 0 #000, 1px -1px 0 #000, -1px 1px 0 #000, 1px 1px 0 #000';
          banner.style.fontSize = '22px';
          banner.style.padding = '14px';
        }
      }, 1000);
    }
  }, 1000);
}

function showUpgradeResult(success, message) {
  console.log('JavaScript: showUpgradeResult called with success:', success, 'message:', message);
  
  // Chiudi la finestra di risultato
  closeUpgradeProgress();
  
  // Invia notifica ox_lib invece di mostrare la finestra
  fetch('https://Runa_System/showUpgradeNotification', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: JSON.stringify({
      success: success,
      message: message
    })
  }).catch(() => {
    // Silently fail if fetch doesn't work
  });
}

function closeUpgradeProgress() {
  const progressWindow = document.getElementById('upgrade-progress');
  
  // Clear all timers immediately including safety timeout
  if (upgradeTimer) {
    clearInterval(upgradeTimer);
    upgradeTimer = null;
  }
  
  if (upgradeProgressTimer) {
    clearTimeout(upgradeProgressTimer);
    upgradeProgressTimer = null;
  }
  
  if (safetyTimeout) {
    clearTimeout(safetyTimeout);
    safetyTimeout = null;
  }
  
  if (progressWindow) {
    progressWindow.classList.add('closing');
    
    setTimeout(() => {
       progressWindow.style.display = 'none';
       progressWindow.classList.remove('closing');
       console.log('JavaScript: Upgrade progress window closed successfully');
     }, 300);
  }
  
  console.log('JavaScript: All timers cleared, upgrade progress window closed');
}

// Event listeners for rune squares will be attached dynamically when updateRunes is received

confirmButton.addEventListener('click', () => {
   if (selectedRune) {
     console.log('JavaScript: Confirm button clicked, switching to phase 2');
     fetch('https://Runa_System/selectRune', {
       method: 'POST',
       headers: {
         'Content-Type': 'application/json; charset=UTF-8',
       },
       body: JSON.stringify({ rune: selectedRune.key })
     }).catch(() => {
       console.log('JavaScript: selectRune request failed');
     });
   }
});

// Close crafting menu button (if exists)
if (closeButton) {
   closeButton.addEventListener('click', () => {
     fetch('https://Runa_System/closeMenu', {
       method: 'POST',
       headers: {
         'Content-Type': 'application/json; charset=UTF-8',
       },
       body: JSON.stringify({})
     }).catch(() => {
       // Silently fail if fetch doesn't work
     });
     hideCraftingMenu();
   });
}

// Upgrade button in phase 2
let upgradeCooldown = false;
if (upgradeButton) {
   upgradeButton.addEventListener('click', () => {
     if (upgradeCooldown) return;

     console.log('JavaScript: Upgrade button clicked');
     upgradeCooldown = true;
     upgradeButton.disabled = true;
     upgradeButton.textContent = 'Incantando... (3)';
     upgradeButton.style.background = 'linear-gradient(45deg, #666666, #888888)';

     let countdown = 3;
     const countdownInterval = setInterval(() => {
       countdown--;
       upgradeButton.textContent = 'Incantando... (' + countdown + ')';
       if (countdown <= 0) {
         clearInterval(countdownInterval);
         upgradeButton.textContent = 'Incanta la Runa';
         upgradeButton.disabled = false;
         upgradeButton.style.background = 'linear-gradient(45deg, #daa520, #ffd700)';
         upgradeCooldown = false;
       }
     }, 1000);

     fetch('https://Runa_System/triggerUpgrade', {
       method: 'POST',
       headers: {
         'Content-Type': 'application/json; charset=UTF-8',
       },
       body: JSON.stringify({ rune: selectedRune.key })
     }).catch(() => {
       console.log('JavaScript: triggerUpgrade request failed');
       // Reset cooldown on error
       clearInterval(countdownInterval);
       upgradeButton.textContent = 'Incanta la Runa';
       upgradeButton.disabled = false;
       upgradeButton.style.background = 'linear-gradient(45deg, #daa520, #ffd700)';
       upgradeCooldown = false;
     });
   });
}

// Close phase 2 button
if (closePhase2Button) {
   closePhase2Button.addEventListener('click', () => {
     fetch('https://Runa_System/closePhase2', {
       method: 'POST',
       headers: {
         'Content-Type': 'application/json; charset=UTF-8',
       },
       body: JSON.stringify({})
     }).catch(() => {
       console.log('JavaScript: closePhase2 request failed');
     });
     hideUpgradePhase2();
   });
}

// Close notification with ESC key
document.addEventListener('keydown', function(event) {
   if (event.key === 'Escape') {
     if (upgradeNotification.style.display === 'block') {
       hideUpgradeNotification();
     } else if (upgradePhase2.style.display === 'block') {
       hideUpgradePhase2();
     } else if (craftingMenu.style.display === 'block') {
       fetch('https://Runa_System/closeMenu', {
         method: 'POST',
         headers: {
           'Content-Type': 'application/json; charset=UTF-8',
         },
         body: JSON.stringify({})
       }).catch(() => {
         // Silently fail if fetch doesn't work
       });
     } else if (document.getElementById('upgrade-progress').style.display === 'block') {
       // Chiudi anche la finestra del risultato con ESC
       closeUpgradeProgress();
     }
   }
});

// Start Function
let numbers = Array.from(Array(60).keys()).map(String);
for (let i = 0; i < 10; i++) {
  numbers[i] = "0" + numbers[i];
}
numbers.push("00");

let time, loop;
let sec = "00",
  min = "00",
  s = 1,
  m = 1,
  startCheck = false,
  resetCheck = false;

function startFunc(m = 0, s = 3) {
  output.style = "display: block";
  resetFunc();

  let minutes = m;
  let seconds = s;
  startCheck = true;

  // Initial display
  updateDisplay();

  loop = setInterval(function () {
    if (seconds === 0) {
      if (minutes === 0) {
        clearInterval(loop);
        startCheck = false;
        resetFunc();
        return;
      }
      minutes--;
      seconds = 59;
    } else {
      seconds--;
    }

    updateDisplay();
  }, 1000);

  // Helper function to update the display
  function updateDisplay() {
    const min = minutes.toString().padStart(2, '0');
    const sec = seconds.toString().padStart(2, '0');
    const timeString = min + ':' + sec;
    output.textContent = timeString;
  }
}

// Stop Function
function stopFunc() {
  output.style = "display: none";

  clearInterval(loop);
  startCheck = false;
}

// Stop timer function (for crafting menu)
function stopCraftingTimer() {
  if (loop) {
    clearInterval(loop);
    loop = null;
  }
  startCheck = false;
  resetCheck = false;
}

// Reset Function
function resetFunc() {
  clearInterval(loop);
  time = "00:00";
  output.textContent = time;
  resetCheck = true;
  startCheck = false;
}

let musicPlayer1 = new Audio();
musicPlayer1.volume = 0.2;
let musicPlayer2 = new Audio();
musicPlayer2.volume = 0.2;
musicPlayer2.addEventListener('ended', function() {
  this.currentTime = 0;
  this.play();
}, false);

function playTickTockSound() {
  musicPlayer2.pause();
  musicPlayer2.currentTime = 0;
  musicPlayer2.src = 'tick-tock.mp3';
  musicPlayer2.load();
  musicPlayer2.play();
}

function stopTickTockSound() {
  musicPlayer2.pause();
}

function playSong(songName) {
  musicPlayer1.pause();
  musicPlayer1.currentTime = 0;
  musicPlayer1.src = songName;
  musicPlayer1.load();
  musicPlayer1.play();
}

function stopSong() {
  musicPlayer1.pause();
  musicPlayer1.currentTime = 0;
}

function show() {
  document.querySelector("body").style = "display: flex";
}

function setParticipantsCounter(val) {
  playersSection.style = 'display: block';
  participantsCounter.textContent = val.toString();
}


window.addEventListener('message', function(event) {
  let item = event.data;

  if (item.show === true) {
    show();
  }

  if (item.show === false) {
    document.querySelector("body").style = "display: none";
  }
  
  if (item.start) {
    startFunc(item.m, item.s);
  }

  if (item.reset) {
    resetFunc();
  }

  if (item.hideTimer) {
    stopFunc();
  }

  if (item.playSong) {
    playSong(item.playSong);
  }

  if (item.stopSong) {
    stopSong();
  }

  if (item.setParticipantsCounter !== undefined) {
    setParticipantsCounter(item.setParticipantsCounter);
  }

  if (item.playTickTockSound) {
    playTickTockSound();
  }

  if (item.stopTickTockSound) {
    stopTickTockSound();
  }

  if (item.playHammerSound) {
    playTickTockSound();
  }

  if (item.hideParticipantsCounter) {
    const playersSection = document.querySelector('#players-section');
    if (playersSection) {
      playersSection.style = "display: none";
    }
  }

  if (item.showLoading) {
    // Rimuoviamo l'indicatore di caricamento inutile
    console.log('JavaScript: Loading indicator request ignored');
  }

  if (item.showCrafting) {
    showCraftingMenu();
  }

  if (item.showCrafting === false) {
    hideCraftingMenu();
  }

  if (item.showPhase2) {
    showUpgradePhase2(item.selectedRune);
  }


  if (item.hideNotification) {
    hideUpgradeNotification();
  }

  if (item.upgradeResult) {
    const result = item.upgradeResult;
    console.log('JavaScript: Received upgradeResult:', result);

    // Delay showing the result message by 2 seconds
    setTimeout(() => {
      // Show result message in phase 2 window
      upgradeResultMessage.style.display = 'block';
      upgradeResultMessage.textContent = result.message;
      upgradeResultMessage.style.color = result.success ? '#00ff00' : '#ff0000';
      upgradeResultMessage.style.background = result.success ? 'rgba(0, 255, 0, 0.1)' : 'rgba(255, 0, 0, 0.1)';
      upgradeResultMessage.style.border = result.success ? '2px solid #00ff00' : '2px solid #ff0000';

      // If no galeoni, close the window
      if (result.noGaleoni) {
        setTimeout(() => {
          hideUpgradePhase2();
        }, 2000);
        return;
      }

      // Update the stone info if upgrade was successful or failed
      if (result.newRune) {
        const runeConfig = {
          'runa_hp': { name: 'Vita', color: '#ff6b6b', image: 'nui://ox_inventory/web/images/runa_hp.png' },
          'runa_danno': { name: 'Danno', color: '#ffa500', image: 'nui://ox_inventory/web/images/runa_danno.png' },
          'runa_mp': { name: 'Mana', color: '#0066ff', image: 'nui://ox_inventory/web/images/runa_mp.png' },
          'runa_cdr': { name: 'Cooldown', color: '#00ff66', image: 'nui://ox_inventory/web/images/runa_cdr.png' },
          'runa_speed': { name: 'Velocità', color: '#ffff00', image: 'nui://ox_inventory/web/images/runa_speed.png' }
        };

        const baseType = result.newRune.type.replace(/_divina$/, '').replace(/_(\d+)$/, '');
        const runeInfo = runeConfig[baseType];
        const currentLevel = result.newRune.level || 0;
        const levelText = currentLevel === 5 ? ' (Divina)' : currentLevel === 0 ? '' : ' (+' + currentLevel + ')';

        document.getElementById('stone-image').innerHTML = `<img src="${runeInfo.image}" style="width: 60px; height: 60px; border-radius: 50%; box-shadow: 0 0 10px ${runeInfo.color};">`;
        document.getElementById('stone-name').textContent = runeInfo.name + levelText;
        document.getElementById('stone-level').textContent = 'Livello Attuale: ' + (currentLevel === 5 ? 'Divina' : currentLevel);

        // Update next level info
        const nextLevel = currentLevel + 1;
        const nextLevelText = nextLevel === 5 ? 'Divina' : '+' + nextLevel;
        document.getElementById('next-level-info').textContent = 'Prossimo Livello: ' + nextLevelText;

        // Update success chance
        const chances = { 0: 100, 1: 80, 2: 60, 3: 40, 4: 20 };
        const chance = chances[currentLevel] || 0;
        document.getElementById('success-chance').textContent = 'Probabilità di Successo: ' + chance + '%';

        // Update selectedRune for next upgrade
        selectedRune = { key: result.newRune.type, name: result.newRune.name };
      }

      // Hide message after 3 seconds
      setTimeout(() => {
        upgradeResultMessage.style.display = 'none';
      }, 3000);
    }, 2000);
  }

  if (item.hideUpgradeProgress) {
    closeUpgradeProgress();
  }

  if (item.galeoniInfo) {
    const galeoniInfo = item.galeoniInfo;
    console.log('JavaScript: Galeoni info received:', galeoniInfo);
    
    // Aggiorna l'interfaccia con le informazioni sui galeoni
    const selectedRuneDiv = document.querySelector('#selected-rune');
    if (selectedRuneDiv) {
      // Trova o crea l'elemento per mostrare i galeoni
      let galeoniDisplay = selectedRuneDiv.querySelector('.galeoni-info');
      if (!galeoniDisplay) {
        galeoniDisplay = document.createElement('div');
        galeoniDisplay.className = 'galeoni-info';
        selectedRuneDiv.insertBefore(galeoniDisplay, selectedRuneDiv.firstChild);
      }
      
      // Crea l'HTML per le informazioni sui galeoni
      const hasEnough = galeoniInfo.hasEnough;
      const galeoniCount = galeoniInfo.count;
      
      galeoniDisplay.innerHTML = `
        <p style="font-size: 18px; color: ${hasEnough ? '#ffd700' : '#ff6b6b'}; text-shadow: 2px 2px 4px #000;">
          Costo Incantesimo: 200 Galeoni
        </p>
        <p style="font-size: 14px; color: ${hasEnough ? '#f4e4bc' : '#ffaaaa'}; margin: 5px 0;">
          I tuoi Galeoni: ${galeoniCount}
        </p>
        ${!hasEnough ? '<p style="font-size: 12px; color: #ff6b6b; font-weight: bold;">⚠️ Non hai abbastanza galeoni!</p>' : ''}
      `;
      
      // Disabilita o abilita il pulsante conferma
      const confirmButton = document.querySelector('#confirm-button');
      if (confirmButton) {
        confirmButton.disabled = !hasEnough;
        confirmButton.style.opacity = hasEnough ? '1' : '0.5';
        confirmButton.style.cursor = hasEnough ? 'pointer' : 'not-allowed';
        confirmButton.style.background = hasEnough ? 
          'linear-gradient(45deg, #daa520, #ffd700)' : 
          'linear-gradient(45deg, #666666, #888888)';
      }
    }
  }

  if (item.updateRunes) {
    console.log('JavaScript: Received updateRunes message');
    console.log('JavaScript: HTML content length:', item.updateRunes.length);
    document.getElementById('rune-selection').innerHTML = item.updateRunes;
    // Re-attach event listeners to new elements
    runeSquares = document.querySelectorAll('.rune-square');
    console.log('JavaScript: Found', runeSquares.length, 'rune squares');
    
    // Clear and repopulate runes array dynamically
    runes = [];
    runeSquares.forEach(square => {
      const runeKey = square.getAttribute('data-rune');
      const runeName = square.querySelector('p')?.textContent?.split(' (')[0]; // Extract base name from display text
      const isDisabled = square.classList.contains('disabled');
      
      console.log('JavaScript: Processing rune - key:', runeKey, 'name:', runeName, 'disabled:', isDisabled);
      
      if (runeKey && runeName && !isDisabled) {
        runes.push({ name: runeName, key: runeKey });
      }
    });
    
    console.log('JavaScript: Populated runes array:', runes);
    
    runeSquares.forEach(square => {
      square.addEventListener('click', () => {
        console.log('JavaScript: Rune square clicked:', square.getAttribute('data-rune'));
        
        // Verifica se la runa è disabilitata
        if (square.classList.contains('disabled')) {
          console.log('JavaScript: Rune is disabled, cannot upgrade');
          // Mostra un messaggio temporaneo
          const tempMessage = document.createElement('div');
          tempMessage.style.cssText = 'position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%); background: rgba(255, 107, 107, 0.9); color: white; padding: 10px 20px; border-radius: 5px; z-index: 9999; font-size: 14px; font-weight: bold;';
          tempMessage.textContent = '⚠️ Questa runa ha già raggiunto il livello massimo!';
          document.body.appendChild(tempMessage);
          
          setTimeout(() => {
            document.body.removeChild(tempMessage);
          }, 2000);
          return;
        }
        
        const runeKey = square.getAttribute('data-rune');
        const rune = runes.find(r => r.key === runeKey);
        if (rune) {
          selectedRune = rune;
          selectedName.textContent = rune.name;
          selectedRuneDiv.style.display = 'block';
          confirmButton.style.display = 'inline-block';
          // Highlight selected
          runeSquares.forEach(s => s.classList.remove('selected'));
          square.classList.add('selected');
          console.log('JavaScript: Selected rune:', rune);
        } else {
          console.log('JavaScript: Rune not found in array for key:', runeKey);
        }
      });
    });
  }
});

console.log('init nui');
// show();