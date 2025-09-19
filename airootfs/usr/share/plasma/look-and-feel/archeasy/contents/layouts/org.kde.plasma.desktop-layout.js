// === ArchEasy default layout for Plasma 6 ===

// 1) Fond d'écran par défaut sur tous les bureaux
(function () {
    var wp = "file:///usr/share/wallpapers/archeasy/contents/images/1920x1080.jpg";
    var ds = desktops();

    for (var i = 0; i < ds.length; i++) {
        var d = ds[i];
        d.wallpaperPlugin = "org.kde.image";
        d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
        d.writeConfig("Image", wp);
    }
})();

// 2) Créer un panel en bas si aucun panel n'existe
(function () {
    if (panels().length > 0) {
        // Il existe déjà un panel (p.ex. si l'utilisateur a un layout conservé)
        return;
    }

    var panel = new Panel;
    panel.location = "bottom";
    panel.height = 44;  // ajuste si tu veux (40–48 est courant)

// Logo pour Kickoff (Application Launcher)
var menu = panel.addWidget("org.kde.plasma.kickoff");
menu.currentConfigGroup = ["General"];
menu.writeConfig("icon", "/usr/share/plasma/look-and-feel/archeasy/contents/barlogo.png");
// ou par nom d’icône si tu l’intègres à un thème : menu.writeConfig("icon", "archeasy")



// Barre des tâches (icônes)
// Barre des tâches (icônes)
var tasks = panel.addWidget("org.kde.plasma.icontasks");

// IMPORTANT : écrire dans le groupe General
tasks.currentConfigGroup = ["General"];

// Liste des lanceurs (virgules, pas de point-virgule)
var pins = [
    "applications:systemsettings.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:org.kde.dolphin.desktop",
    "applications:firefox.desktop"
].join(",");

// Contournement Plasma 6 : vider puis écrire 2x + reload
tasks.writeConfig("launchers", "");
tasks.writeConfig("launchers", pins);
tasks.writeConfig("launchers", pins);
tasks.reloadConfig();


// Espaceur extensible pour pousser la systray/horloge à droite
var spacer = panel.addWidget("org.kde.plasma.panelspacer");
spacer.currentConfigGroup = ["Configuration"];
spacer.writeConfig("expanding", "true");

// Zone de notifications (systray)
var systray = panel.addWidget("org.kde.plasma.systemtray");
// (Optionnel) tu peux forcer des éléments de la systray ici si besoin

// Horloge
var clock = panel.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
// 24h (true/false). Si tu préfères laisser selon la locale, commente cette ligne.
clock.writeConfig("use24hFormat", "true");
})();
