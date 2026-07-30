pragma Singleton

import QtQuick
import Quickshell

// UI strings.
//
// The active language comes from Config.effectiveLocale. To add a
// translation, append a section to `table`; any missing key falls back
// to English automatically, so partial translations are fine.
Singleton {
    id: root

    readonly property var table: ({
            en: {
                password: "Password",
                wrongPassword: "Incorrect password",
                capsLockOn: "Caps Lock is on",
                noSessions: "No sessions available",
                signedIn: "Signed in",
                bridgeMissing: "greetd bridge is not running",
                extraInput: "Additional input required",
                suspend: "Suspend",
                reboot: "Restart",
                shutdown: "Shut down",
                mockNotice: "mock mode · no real login · password:"
            },
            ru: {
                password: "Пароль",
                wrongPassword: "Неверный пароль",
                capsLockOn: "Включён Caps Lock",
                noSessions: "Нет доступных сессий",
                signedIn: "Вход выполнен",
                bridgeMissing: "мост к greetd не запущен",
                extraInput: "Требуется дополнительный ввод",
                suspend: "Сон",
                reboot: "Перезагрузка",
                shutdown: "Выключение",
                mockNotice: "mock-режим · вход не выполняется · пароль:"
            }
        })

    function tr(key: string): string {
        const lang = table[Config.effectiveLocale] ?? table.en;
        return lang[key] ?? table.en[key] ?? key;
    }
}
