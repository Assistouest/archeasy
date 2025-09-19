import QtQuick 2.15

Item {
    id: root
    width: 1920; height: 1080

    // Fond (fallback noir si l'image manque)
    Rectangle { anchors.fill: parent; color: "black" }


    // --- Spinner : arc quasi plein qui tourne ---
    Item {
        id: spinner
        width: 50; height: 50
        anchors.centerIn: parent
        transformOrigin: Item.Center

        // Réglages
        property real sweepDeg: 330
        property real thickness: 6
        property color color: "white"

        // Rotation continue
        NumberAnimation on rotation {
            from: 0; to: 360
            duration: 1200
            loops: Animation.Infinite
            running: true
        }

        Canvas {
            id: arc
            anchors.fill: parent
            antialiasing: true

            property real radius: Math.min(width, height)/2 - spinner.thickness/2

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                ctx.beginPath();
                ctx.lineWidth = spinner.thickness;
                ctx.lineCap = "round";
                ctx.strokeStyle = spinner.color;

                var cx = width/2, cy = height/2;
                var start = -Math.PI/2; // en haut
                var end   = start + spinner.sweepDeg * Math.PI/180;

                ctx.arc(cx, cy, arc.radius, start, end, false);
                ctx.stroke();
            }

            Component.onCompleted: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onVisibleChanged: requestPaint()
            Connections {
                target: spinner
                function onSweepDegChanged(){ arc.requestPaint() }
                function onThicknessChanged(){ arc.requestPaint() }
                function onColorChanged(){ arc.requestPaint() }
            }
        }
    }

    // --- Texte fixe + zone de points à largeur constante ---
    Item {
        id: footer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 80
        // largeur = texte + largeur fixe des 3 points
        width: msg.paintedWidth + dots.implicitWidth + 4
        height: Math.max(msg.paintedHeight, dots.implicitHeight)

        // Compteur de points (1 -> 2 -> 3 -> 1 ...)
        property int count: 1
        Timer {
            interval: 320
            running: true
            repeat: true
            onTriggered: footer.count = (footer.count % 3) + 1
        }

        // Texte centré dans le conteneur — NE BOUGE PAS
        Text {
            id: msg
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Initialisation des modules Plasma"
            color: "white"
            font.pixelSize: 28
        }

        // Zone des trois points, largeur constante
        Row {
            id: dots
            anchors.verticalCenter: msg.verticalCenter
            // Positionnée juste à droite du texte, sans influencer sa centrage
            x: msg.x + msg.paintedWidth + 4
            spacing: 2

            // Toujours 3 points présents : on change seulement l'opacité
            Text {
                text: "."
                color: "white"
                font.pixelSize: 28
                opacity: footer.count >= 1 ? 1 : 0
            }
            Text {
                text: "."
                color: "white"
                font.pixelSize: 28
                opacity: footer.count >= 2 ? 1 : 0
            }
            Text {
                text: "."
                color: "white"
                font.pixelSize: 28
                opacity: footer.count >= 3 ? 1 : 0
            }
        }
    }
}
