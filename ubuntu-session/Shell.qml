/*
 * Copyright (C) 2013 Canonical, Ltd.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.0
import Ubuntu.Components 0.1

// IconRunner Begin
import HudClient 0.1
// IconRunner End

import "Dash"
import "Applications"
import "Applications/applications.js" as ApplicationsModel
import "Greeter"
import "Launcher"
import "Panel"
import "Hud"
import "Components"
import "Components/Math.js" as MathLocal
import "Bottombar"
import "SideStage"

FocusScope {
    id: shell

    // IconRunner Begin
    signal actionTriggered(int action)
    // IconRunner End

    // this is only here to select the width / height of the window if not running fullscreen
    property bool tablet: false
    width: tablet ? units.gu(160) : units.gu(40)
    height: tablet ? units.gu(100) : units.gu(71)

    property real edgeSize: units.gu(2)
    property url background: shell.width >= units.gu(60) ? "graphics/tablet_background.jpg" : "graphics/phone_background.jpg"
    readonly property real panelHeight: panel.panelHeight

    property bool dashShown: dash.shown
    property bool stageScreenshotsReady: {
        if (sideStage.shown) {
            if (mainStage.applications.count > 0) {
                return mainStage.usingScreenshots && sideStage.usingScreenshots;
            } else {
                return sideStage.usingScreenshots;
            }
        } else {
            return mainStage.usingScreenshots;
        }
    }

    property ListModel searchHistory: SearchHistoryModel {}

    // if running in Hybris environment, can offload running app management to it, else we fake it
    property var applicationManager
    // whether or not "import Ubuntu.Application" would work
    property bool importUbuntuApplicationAvailable: checkImportUbuntuApplicationAvailable()

    /* Checks if the "Ubuntu.Application" plugin is available, and if so use it for application management.
       Returns true if the plugin is available, false otherwise.

       This works around the lack of conditional imports in QML.
       Ref.: https://bugreports.qt-project.org/browse/QTBUG-16854
    */
    function checkImportUbuntuApplicationAvailable() {
        try {
            var object = Qt.createQmlObject('import Ubuntu.Application 0.1; import QtQuick 2.0; QtObject {}', shell, "");
            object.destroy();
            return true;
        } catch (error) {
            console.log("NOTICE: The Ubuntu.Application plugin was not found, so all window management is emulated in this application.\n\
This emulation will not be perfect, you *must* not trust it. To be safe always test on a device with Ubuntu.Application available.");
            return false;
        }
    }

    Component.onCompleted: {
        var component;
        if (!importUbuntuApplicationAvailable) {
            component = Qt.createComponent("Components/ApplicationManagerFake.qml");
        } else {
            component = Qt.createComponent("Components/ApplicationManagerWrapper.qml");
        }

        applicationManager = component.createObject(shell);
        applicationManager.sideStageEnabled = Qt.binding(function() { return sideStage.enabled })

        // FIXME: if application focused before shell starts, shell draws on top of it only.
        // We should detect already running applications on shell start and bring them to the front.
        applicationManager.unfocusCurrentApplication();
    }

    readonly property bool fullscreenMode: {
        if (greeter.shown) {
            return false;
        } else if (mainStage.usingScreenshots) { // Window Manager animating so want to re-evaluate fullscreen mode
            return mainStage.switchingFromFullscreenToFullscreen;
        } else if (applicationManager.mainStageFocusedApplication) {
            return applicationManager.mainStageFocusedApplication.fullscreen;
        } else {
            return false;
        }
    }

    Connections {
        target: applicationManager
        ignoreUnknownSignals: true
        onFocusRequested: {
            shell.activateApplication(desktopFile);
        }
    }

    function activateApplication(desktopFile, argument) {
        if (applicationManager) {
            var application;
            application = applicationManager.activateApplication(desktopFile, argument);
            if (application == null) {
                return;
            }
            if (application.stage == ApplicationsModel.MainStage || !sideStage.enabled) {
                mainStage.activateApplication(desktopFile);
            } else {
                sideStage.activateApplication(desktopFile);
            }
            stages.show();
        }
    }

    VolumeControl {
        id: _volumeControl
    }

    Keys.onVolumeUpPressed: _volumeControl.volumeUp()
    Keys.onVolumeDownPressed: _volumeControl.volumeDown()

    // IconRunner Begin
	//    Keys.onBackPressed: hud.show()
    // Back = (Home 0x01000061)
    // Menu = (Menu 0x01000055)

    Keys.onReleased: {
        if (event.key == Qt.Key_PowerOff) {
            greeter.show()
        }

        // i9300 Menu Key? find right keycode if not working
        if (event.key == Qt.Key_Menu) {
            if (hud.shown == true) {
                hud.hide()
            }
            else {
                hud.show()
            }
        }

        // i9300 Menu Key? find right keycode if not working
        if (event.key == Qt.Key_Back) {
            // Here's where I left off. I'm trying to mimic the close button in ToolBar.qml
            // actionTriggered(HudClient.QuitToolBarAction)

            // For now we'll let the home button lock the screen.
            greeter.show()
        }

        // I'm using these to probe for the other two keys on the i777. So far no luck :(
        if (event.key == Qt.Key_Search) {
            greeter.show()
        }

        if (event.key == Qt.Key_Home) {
            hud.show()
        }

        if (event.key == Qt.Key_Period) {
            greeter.show()
        }
    }
    // IconRunner End

    // for Desktop only, to emulate window management when hybris not available
    Item {
        id: fakeWindowContainer

        property real sideStageWidth: sideStage.width

        anchors.fill: parent
        z: -1000
    }

    Item {
        id: underlay

        anchors.fill: parent
        visible: !(panel.indicators.fullyOpened && shell.width <= panel.indicatorsMenuWidth)
                 && (stages.fullyHidden
                     || (stages.fullyShown && mainStage.usingScreenshots)
                     || !stages.fullyShown && (mainStage.usingScreenshots || (sideStage.shown && sideStage.usingScreenshots)))

        Image {
            id: backgroundImage
            source: shell.background
            sourceSize.width: parent.width
            sourceSize.height: parent.height
            anchors.fill: parent
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: dash.disappearingAnimationProgress
        }

        Dash {
            id: dash

            available: !greeter.shown
            hides: [stages, launcher, panel.indicators]
            shown: disappearingAnimationProgress !== 1.0
            enabled: disappearingAnimationProgress === 0.0
            // FIXME: unfocus all applications when going back to the dash
            onEnabledChanged: {
                if (enabled) {
                    shell.applicationManager.unfocusCurrentApplication()
                }
            }

            anchors {
                fill: parent
                topMargin: panel.panelHeight
            }

            contentScale: 1.0 - 0.2 * disappearingAnimationProgress
            opacity: 1.0 - disappearingAnimationProgress
            property real disappearingAnimationProgress: ((greeter.shown) ? greeterRevealer.animatedProgress : stagesRevealer.animatedProgress)
            // FIXME: only necessary because stagesRevealer.animatedProgress and
            // greeterRevealer.animatedProgress are not animated
            Behavior on disappearingAnimationProgress { SmoothedAnimation { velocity: 5 }}
        }
    }


    Item {

        width: parent.width
        height: parent.height
        x: launcher.progress
        Behavior on x {SmoothedAnimation{velocity: 600}}


        Showable {
            id: stages

            property bool fullyShown: shown && stages[stagesRevealer.boundProperty] == stagesRevealer.openedValue
                                      && parent.x == 0
            property bool fullyHidden: !shown && stages[stagesRevealer.boundProperty] == stagesRevealer.closedValue
            available: !greeter.shown
            hides: [launcher, panel.indicators]
            shown: false
            opacity: 1.0
            showAnimation: StandardAnimation { property: "x"; duration: 350; to: stagesRevealer.openedValue; easing.type: Easing.OutCubic }
            hideAnimation: StandardAnimation { property: "x"; duration: 350; to: stagesRevealer.closedValue; easing.type: Easing.OutCubic }

            width: parent.width
            height: parent.height

            // close the stages when no focused application remains
            Connections {
                target: shell.applicationManager
                onMainStageFocusedApplicationChanged: stages.closeIfNoApplications()
                onSideStageFocusedApplicationChanged: stages.closeIfNoApplications()
                ignoreUnknownSignals: true
            }

            function closeIfNoApplications() {
                if (!shell.applicationManager.mainStageFocusedApplication
                 && !shell.applicationManager.sideStageFocusedApplication
                 && shell.applicationManager.mainStageApplications.count == 0
                 && shell.applicationManager.sideStageApplications.count == 0) {
                    stages.hide();
                }
            }

            // show the stages when an application gets the focus
            Connections {
                target: shell.applicationManager
                onMainStageFocusedApplicationChanged: {
                    if (shell.applicationManager.mainStageFocusedApplication) {
                        mainStage.show();
                        stages.show();
                    }
                }
                onSideStageFocusedApplicationChanged: {
                    if (shell.applicationManager.sideStageFocusedApplication) {
                        sideStage.show();
                        stages.show();
                    }
                }
                ignoreUnknownSignals: true
            }


            Stage {
                id: mainStage

                anchors.fill: parent
                fullyShown: stages.fullyShown
                shouldUseScreenshots: !fullyShown
                rightEdgeEnabled: !sideStage.enabled

                applicationManager: shell.applicationManager
                rightEdgeDraggingAreaWidth: shell.edgeSize
                normalApplicationY: shell.panelHeight

                shown: true
                function show() {
                    stages.show();
                }
                function showWithoutAnimation() {
                    stages.showWithoutAnimation();
                }
                function hide() {
                }

                // FIXME: workaround the fact that focusing a main stage application
                // raises its surface on top of all other surfaces including the ones
                // that belong to side stage applications.
                onFocusedApplicationChanged: {
                    if (focusedApplication && sideStage.focusedApplication && sideStage.fullyShown) {
                        shell.applicationManager.focusApplication(sideStage.focusedApplication);
                    }
                }
            }

            SideStage {
                id: sideStage

                applicationManager: shell.applicationManager
                rightEdgeDraggingAreaWidth: shell.edgeSize
                normalApplicationY: shell.panelHeight

                onShownChanged: {
                    if (!shown && mainStage.applications.count == 0) {
                        stages.hide();
                    }
                }
                // FIXME: when hiding the side stage, refocus the main stage
                // application so that it goes in front of the side stage
                // application and hides it
                onFullyShownChanged: {
                    if (!fullyShown && stages.fullyShown && sideStage.focusedApplication != null) {
                        shell.applicationManager.focusApplication(mainStage.focusedApplication);
                    }
                }

                enabled: shell.width >= units.gu(60)
                visible: enabled
                fullyShown: stages.fullyShown && shown
                            && sideStage[sideStageRevealer.boundProperty] == sideStageRevealer.openedValue
                shouldUseScreenshots: !fullyShown || mainStage.usingScreenshots || sideStageRevealer.pressed

                available: !greeter.shown && enabled
                hides: [launcher, panel.indicators]
                shown: false
                showAnimation: StandardAnimation { property: "x"; duration: 350; to: sideStageRevealer.openedValue; easing.type: Easing.OutQuint }
                hideAnimation: StandardAnimation { property: "x"; duration: 350; to: sideStageRevealer.closedValue; easing.type: Easing.OutQuint }

                width: units.gu(40)
                height: stages.height
                handleExpanded: sideStageRevealer.pressed
            }

            Revealer {
                id: sideStageRevealer

                enabled: mainStage.applications.count > 0 && sideStage.applications.count > 0
                         && sideStage.available
                direction: Qt.RightToLeft
                openedValue: parent.width - sideStage.width
                hintDisplacement: units.gu(3)
                /* The size of the sidestage handle needs to be bigger than the
                   typical size used for edge detection otherwise it is really
                   hard to grab.
                */
                handleSize: sideStage.shown ? units.gu(4) : shell.edgeSize
                closedValue: parent.width + sideStage.handleSizeCollapsed
                target: sideStage
                x: parent.width - width
                width: sideStage.width + handleSize * 0.7
                height: sideStage.height
                orientation: Qt.Horizontal
            }
        }
    }


    Revealer {
        id: stagesRevealer

        property real animatedProgress: MathLocal.clamp((-dragPosition - launcher.progress) / closedValue, 0, 1)
        enabled: mainStage.applications.count > 0 || sideStage.applications.count > 0
        direction: Qt.RightToLeft
        openedValue: 0
        hintDisplacement: units.gu(3)
        handleSize: shell.edgeSize
        closedValue: width
        target: stages
        width: stages.width
        height: stages.height
        orientation: Qt.Horizontal
    }

    Greeter {
        id: greeter

        available: true
        hides: [launcher, panel.indicators, hud]
        shown: true
        showAnimation: StandardAnimation { property: "x"; to: greeterRevealer.openedValue }
        hideAnimation: StandardAnimation { property: "x"; to: greeterRevealer.closedValue }

        y: panel.panelHeight
        width: parent.width
        height: parent.height - panel.panelHeight

        onShownChanged: if (shown) greeter.forceActiveFocus()
        
        onUnlocked: greeter.hide()
        onSelected: shell.background = greeter.model.get(uid).background;

    }

    Revealer {
        id: greeterRevealer

        property real animatedProgress: MathLocal.clamp(-dragPosition / closedValue, 0, 1)
        target: greeter
        width: greeter.width
        height: greeter.height
        handleSize: shell.edgeSize
        orientation: Qt.Horizontal
        visible: greeter.shown
        enabled: !greeter.locked
    }

    Item {
        id: overlay

        anchors.fill: parent

        Panel {
            id: panel
            anchors.fill: parent //because this draws indicator menus
            indicatorsMenuWidth: parent.width > units.gu(60) ? units.gu(40) : parent.width
            indicators {
                hides: [launcher]
                available: !greeter.shown
            }
            fullscreenMode: shell.fullscreenMode
            searchEnabled: !greeter.shown

            InputFilterArea {
                anchors.fill: parent
                blockInput: panel.indicators.shown
            }
        }

        Hud {
            id: hud

            width: parent.width > units.gu(60) ? units.gu(40) : parent.width
            height: parent.height

            available: !greeter.shown && !panel.indicators.shown
            shown: false
            showAnimation: StandardAnimation { property: "y"; duration: hud.showableAnimationDuration; to: 0; easing.type: Easing.Linear }
            hideAnimation: StandardAnimation { property: "y"; duration: hud.showableAnimationDuration; to: hudRevealer.closedValue; easing.type: Easing.Linear }

            Connections {
                target: shell.applicationManager
                onMainStageFocusedApplicationChanged: hud.hide()
                onSideStageFocusedApplicationChanged: hud.hide()
            }

            InputFilterArea {
                anchors.fill: parent
                blockInput: hud.shown
            }
        }

        Revealer {
            id: hudRevealer

            enabled: hud.shown
            width: hud.width
            anchors.left: hud.left
            height: parent.height
            target: hud.revealerTarget
            closedValue: height
            openedValue: 0
            direction: Qt.RightToLeft
            orientation: Qt.Vertical
            handleSize: hud.handleHeight
            onCloseClicked: target.hide()
        }

        Bottombar {
            theHud: hud
            sideStageWidth: sideStage.width
            anchors.fill: parent
            enabled: !panel.indicators.shown
        }

        Launcher {
            id: launcher

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width
            applicationFocused: stages.shown
            shortcutsWidth: units.gu(9)
            shortcutsThreshold: shell.edgeSize
            iconPath: "graphics/applicationIcons"
            available: !greeter.locked
            onDashItemSelected: {
                greeter.hide()
                // Animate if moving between application and dash
                if (!stages.shown) {
                    dash.setCurrentLens("home.lens", true, false)
                } else {
                    dash.setCurrentLens("home.lens", false, false)
                }
                stages.hide();
            }
            onDash: {
                greeter.hide()
                stages.hide();
            }
            onLauncherApplicationSelected:{
                greeter.hide()
                shell.activateApplication(name)
            }
            onStateChanged: {
                if (state == "spreadMoving") {
                    dash.setCurrentLens("applications.lens", false, true)
                }
            }
            onShownChanged: {
                if (shown) {
                    panel.indicators.hide()
                    hud.hide()
                }
            }
        }

        InputFilterArea {
            blockInput: launcher.shown
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }
            width: launcher.shortcutsWidth
        }
    }

    focus: true

    InputFilterArea {
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
        }
        width: shell.edgeSize
        blockInput: true
    }

    InputFilterArea {
        anchors {
            top: parent.top
            bottom: parent.bottom
            right: parent.right
        }
        width: shell.edgeSize
        blockInput: true
    }

    //FIXME: This should be handled in the input stack, keyboard shouldnt propagate
    MouseArea {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: shell.applicationManager ? shell.applicationManager.keyboardHeight : 0

        enabled: shell.applicationManager && shell.applicationManager.keyboardVisible
    }
}