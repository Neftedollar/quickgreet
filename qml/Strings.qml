pragma Singleton

import QtQuick
import Quickshell

// UI strings.
//
// Each language owns everything the rest of the code needs to know about
// it: the visible text and, under `_locale`, the tag used for formatting
// dates. Adding a language is therefore a single object here — no edits
// anywhere else, which is what the previous layout required.
//
// Missing keys fall back to English, so partial translations are welcome.
// Every language listed is left-to-right; adding an RTL one additionally
// needs LayoutMirroring in the views.
Singleton {
    id: root

    readonly property var table: ({
            en: {
                _locale: "en_GB",
                password: "Password",
                wrongPassword: "Incorrect password",
                loginFailed: "Sign-in failed",
                timedOut: "No response — try again",
                capsLockOn: "Caps Lock is on",
                noSessions: "No sessions available",
                noUsers: "No accounts found",
                signedIn: "Signed in",
                bridgeMissing: "Cannot reach the login service",
                layoutUnknown: "Keyboard layout unknown",
                iconFontMissing: "Icon font missing — icons appear as text",
                suspend: "Suspend",
                reboot: "Restart",
                shutdown: "Shut down",
                mockNotice: "mock mode · no real login · password: %1"
            },
            ru: {
                _locale: "ru_RU",
                password: "Пароль",
                wrongPassword: "Неверный пароль",
                loginFailed: "Не удалось войти",
                timedOut: "Нет ответа — попробуйте ещё раз",
                capsLockOn: "Включён Caps Lock",
                noSessions: "Нет доступных сессий",
                noUsers: "Учётные записи не найдены",
                signedIn: "Вход выполнен",
                bridgeMissing: "Служба входа недоступна",
                layoutUnknown: "Раскладка неизвестна",
                iconFontMissing: "Шрифт значков не установлен — иконки показаны текстом",
                suspend: "Сон",
                reboot: "Перезагрузка",
                shutdown: "Выключение",
                mockNotice: "mock-режим · вход не выполняется · пароль: %1"
            },
            uk: {
                _locale: "uk_UA",
                password: "Пароль",
                wrongPassword: "Невірний пароль",
                loginFailed: "Не вдалося увійти",
                timedOut: "Немає відповіді — спробуйте ще раз",
                capsLockOn: "Увімкнено Caps Lock",
                noSessions: "Немає доступних сеансів",
                noUsers: "Облікові записи не знайдено",
                signedIn: "Вхід виконано",
                bridgeMissing: "Служба входу недоступна",
                layoutUnknown: "Розкладка невідома",
                iconFontMissing: "Шрифт піктограм відсутній — значки показано текстом",
                suspend: "Сон",
                reboot: "Перезавантаження",
                shutdown: "Вимкнення",
                mockNotice: "тестовий режим · вхід не виконується · пароль: %1"
            },
            de: {
                _locale: "de_DE",
                password: "Passwort",
                wrongPassword: "Falsches Passwort",
                loginFailed: "Anmeldung fehlgeschlagen",
                timedOut: "Keine Antwort — bitte erneut versuchen",
                capsLockOn: "Feststelltaste ist aktiv",
                noSessions: "Keine Sitzungen verfügbar",
                noUsers: "Keine Benutzerkonten gefunden",
                signedIn: "Angemeldet",
                bridgeMissing: "Anmeldedienst nicht erreichbar",
                layoutUnknown: "Tastaturbelegung unbekannt",
                iconFontMissing: "Symbolschriftart fehlt — Symbole erscheinen als Text",
                suspend: "Bereitschaft",
                reboot: "Neu starten",
                shutdown: "Herunterfahren",
                mockNotice: "Testmodus · keine echte Anmeldung · Passwort: %1"
            },
            fr: {
                _locale: "fr_FR",
                password: "Mot de passe",
                wrongPassword: "Mot de passe incorrect",
                loginFailed: "Échec de la connexion",
                timedOut: "Pas de réponse — réessayez",
                capsLockOn: "Verrouillage majuscules activé",
                noSessions: "Aucune session disponible",
                noUsers: "Aucun compte trouvé",
                signedIn: "Connecté",
                bridgeMissing: "Service de connexion inaccessible",
                layoutUnknown: "Disposition du clavier inconnue",
                iconFontMissing: "Police d’icônes absente — les icônes s’affichent en texte",
                suspend: "Veille",
                reboot: "Redémarrer",
                shutdown: "Éteindre",
                mockNotice: "mode test · aucune connexion réelle · mot de passe : %1"
            },
            es: {
                _locale: "es_ES",
                password: "Contraseña",
                wrongPassword: "Contraseña incorrecta",
                loginFailed: "Error al iniciar sesión",
                timedOut: "Sin respuesta: inténtelo de nuevo",
                capsLockOn: "Bloq Mayús activado",
                noSessions: "No hay sesiones disponibles",
                noUsers: "No se encontraron cuentas",
                signedIn: "Sesión iniciada",
                bridgeMissing: "No se puede acceder al servicio de inicio de sesión",
                layoutUnknown: "Distribución de teclado desconocida",
                iconFontMissing: "Falta la fuente de iconos: se muestran como texto",
                suspend: "Suspender",
                reboot: "Reiniciar",
                shutdown: "Apagar",
                mockNotice: "modo de prueba · sin inicio real · contraseña: %1"
            },
            it: {
                _locale: "it_IT",
                password: "Password",
                wrongPassword: "Password errata",
                loginFailed: "Accesso non riuscito",
                timedOut: "Nessuna risposta: riprova",
                capsLockOn: "Blocco maiuscole attivo",
                noSessions: "Nessuna sessione disponibile",
                noUsers: "Nessun account trovato",
                signedIn: "Accesso effettuato",
                bridgeMissing: "Servizio di accesso non raggiungibile",
                layoutUnknown: "Layout di tastiera sconosciuto",
                iconFontMissing: "Font delle icone mancante: le icone appaiono come testo",
                suspend: "Sospendi",
                reboot: "Riavvia",
                shutdown: "Arresta",
                mockNotice: "modalità di prova · nessun accesso reale · password: %1"
            },
            pt: {
                _locale: "pt_BR",
                password: "Senha",
                wrongPassword: "Senha incorreta",
                loginFailed: "Falha ao entrar",
                timedOut: "Sem resposta — tente novamente",
                capsLockOn: "Caps Lock ativado",
                noSessions: "Nenhuma sessão disponível",
                noUsers: "Nenhuma conta encontrada",
                signedIn: "Conectado",
                bridgeMissing: "Não foi possível acessar o serviço de login",
                layoutUnknown: "Layout de teclado desconhecido",
                iconFontMissing: "Fonte de ícones ausente — ícones aparecem como texto",
                suspend: "Suspender",
                reboot: "Reiniciar",
                shutdown: "Desligar",
                mockNotice: "modo de teste · sem login real · senha: %1"
            },
            pl: {
                _locale: "pl_PL",
                password: "Hasło",
                wrongPassword: "Nieprawidłowe hasło",
                loginFailed: "Logowanie nie powiodło się",
                timedOut: "Brak odpowiedzi — spróbuj ponownie",
                capsLockOn: "Caps Lock jest włączony",
                noSessions: "Brak dostępnych sesji",
                noUsers: "Nie znaleziono kont",
                signedIn: "Zalogowano",
                bridgeMissing: "Nie można połączyć się z usługą logowania",
                layoutUnknown: "Nieznany układ klawiatury",
                iconFontMissing: "Brak czcionki ikon — ikony wyświetlane jako tekst",
                suspend: "Uśpij",
                reboot: "Uruchom ponownie",
                shutdown: "Wyłącz",
                mockNotice: "tryb testowy · brak rzeczywistego logowania · hasło: %1"
            },
            cs: {
                _locale: "cs_CZ",
                password: "Heslo",
                wrongPassword: "Nesprávné heslo",
                loginFailed: "Přihlášení selhalo",
                timedOut: "Bez odpovědi — zkuste to znovu",
                capsLockOn: "Caps Lock je zapnutý",
                noSessions: "Nejsou dostupné žádné relace",
                noUsers: "Nebyly nalezeny žádné účty",
                signedIn: "Přihlášeno",
                bridgeMissing: "Přihlašovací službu nelze kontaktovat",
                layoutUnknown: "Neznámé rozložení klávesnice",
                iconFontMissing: "Chybí písmo ikon — ikony se zobrazují jako text",
                suspend: "Uspat",
                reboot: "Restartovat",
                shutdown: "Vypnout",
                mockNotice: "testovací režim · bez skutečného přihlášení · heslo: %1"
            },
            nl: {
                _locale: "nl_NL",
                password: "Wachtwoord",
                wrongPassword: "Onjuist wachtwoord",
                loginFailed: "Aanmelden mislukt",
                timedOut: "Geen reactie — probeer opnieuw",
                capsLockOn: "Caps Lock staat aan",
                noSessions: "Geen sessies beschikbaar",
                noUsers: "Geen accounts gevonden",
                signedIn: "Aangemeld",
                bridgeMissing: "Aanmeldservice niet bereikbaar",
                layoutUnknown: "Toetsenbordindeling onbekend",
                iconFontMissing: "Pictogramlettertype ontbreekt — pictogrammen tonen als tekst",
                suspend: "Slaapstand",
                reboot: "Herstarten",
                shutdown: "Afsluiten",
                mockNotice: "testmodus · geen echte aanmelding · wachtwoord: %1"
            },
            tr: {
                _locale: "tr_TR",
                password: "Parola",
                wrongPassword: "Hatalı parola",
                loginFailed: "Oturum açılamadı",
                timedOut: "Yanıt yok — yeniden deneyin",
                capsLockOn: "Caps Lock açık",
                noSessions: "Kullanılabilir oturum yok",
                noUsers: "Hesap bulunamadı",
                signedIn: "Oturum açıldı",
                bridgeMissing: "Oturum açma hizmetine ulaşılamıyor",
                layoutUnknown: "Klavye düzeni bilinmiyor",
                iconFontMissing: "Simge yazı tipi yok — simgeler metin olarak görünüyor",
                suspend: "Uyku",
                reboot: "Yeniden başlat",
                shutdown: "Kapat",
                mockNotice: "test kipi · gerçek oturum açma yok · parola: %1"
            },
            sv: {
                _locale: "sv_SE",
                password: "Lösenord",
                wrongPassword: "Fel lösenord",
                loginFailed: "Inloggningen misslyckades",
                timedOut: "Inget svar — försök igen",
                capsLockOn: "Caps Lock är på",
                noSessions: "Inga sessioner tillgängliga",
                noUsers: "Inga konton hittades",
                signedIn: "Inloggad",
                bridgeMissing: "Kan inte nå inloggningstjänsten",
                layoutUnknown: "Okänd tangentbordslayout",
                iconFontMissing: "Ikontypsnitt saknas — ikoner visas som text",
                suspend: "Vänteläge",
                reboot: "Starta om",
                shutdown: "Stäng av",
                mockNotice: "testläge · ingen riktig inloggning · lösenord: %1"
            },
            zh: {
                _locale: "zh_CN",
                password: "密码",
                wrongPassword: "密码错误",
                loginFailed: "登录失败",
                timedOut: "无响应，请重试",
                capsLockOn: "大写锁定已开启",
                noSessions: "没有可用会话",
                noUsers: "未找到账户",
                signedIn: "已登录",
                bridgeMissing: "无法连接登录服务",
                layoutUnknown: "键盘布局未知",
                iconFontMissing: "缺少图标字体，图标显示为文字",
                suspend: "睡眠",
                reboot: "重启",
                shutdown: "关机",
                mockNotice: "模拟模式 · 不会真正登录 · 密码：%1"
            },
            ja: {
                _locale: "ja_JP",
                password: "パスワード",
                wrongPassword: "パスワードが違います",
                loginFailed: "サインインできませんでした",
                timedOut: "応答がありません。再試行してください",
                capsLockOn: "Caps Lock がオンです",
                noSessions: "利用できるセッションがありません",
                noUsers: "アカウントが見つかりません",
                signedIn: "サインインしました",
                bridgeMissing: "ログインサービスに接続できません",
                layoutUnknown: "キーボードレイアウトが不明です",
                iconFontMissing: "アイコンフォントがありません。アイコンは文字で表示されます",
                suspend: "スリープ",
                reboot: "再起動",
                shutdown: "シャットダウン",
                mockNotice: "モックモード · 実際のログインは行われません · パスワード: %1"
            }
        })

    readonly property var languages: Object.keys(table)

    // The active language. Resolution lives here rather than in Config so
    // that a new language is one object in this file and nothing else.
    readonly property string language: {
        const want = Config.locale;

        if (want && want !== "auto") {
            if (table[want])
                return want;
            console.warn("quickgreet: unknown locale", want + "; known:", languages.join(", "));
        }

        // Qt.locale().name is like "ru_RU"; the language part is enough.
        const sys = Qt.locale().name.slice(0, 2);
        return table[sys] ? sys : "en";
    }

    // Date/time formatting tag for the active language.
    readonly property string qtLocale: (table[language] ?? table.en)._locale

    // tr("key") or tr("key", arg1, arg2) with %1/%2 placeholders.
    //
    // Deliberately untyped: a QML function with type annotations has fixed
    // arity, so the extra arguments never reach `arguments` and every
    // placeholder is left standing in the output.
    function tr(key) {
        const lang = table[language] ?? table.en;
        let out = lang[key] ?? table.en[key] ?? key;

        for (let i = 1; i < arguments.length; i++)
            out = out.replace("%" + i, arguments[i]);

        return out;
    }
}
