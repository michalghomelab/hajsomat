# Redesign „Automat” Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Przebudować wygląd frontendu hajsomat na tożsamość „Automat” (granat + złoto, Bricolage Grotesque) z nowym hero, tabelką z udziałami, uporządkowanym wykresem i jednym menu ustawień.

**Architecture:** Własne motywy daisyUI o nazwach `light`/`dark` (logika `data-theme` bez zmian), nowe czyste moduły JS (`allocation.js`, `theme.svelte.js`, `chartOptions.js`, helpery w `format.js`) z testami Vitest, nowe małe komponenty (`Hero`, `ShareBar`, `SettingsMenu`) używane przez oba widoki. Backend bez zmian.

**Tech Stack:** Svelte 5 (runes), Tailwind v4 + daisyUI 5, ApexCharts 7, lucide, Vitest + @testing-library/svelte (jsdom), `@fontsource-variable/bricolage-grotesque`.

**Spec:** `docs/superpowers/specs/2026-11-03-redesign-automat-design.md` (+ makieta `docs/superpowers/specs/2026-11-03-redesign-automat-mockup.html`)

## Global Constraints

- Tylko `web/`. Zero zmian w `api/`, API, routingu (`#/portfolio/:id`), WebSocketach.
- Wszystko przez Docker Compose: testy `docker compose run --rm --no-deps web npx vitest run`, check `docker compose run --rm --no-deps web npm run check`. Po zmianie `package.json`: `docker compose build web` przed uruchomieniem.
- Jedyna nowa zależność: `@fontsource-variable/bricolage-grotesque` (font lokalny, działa offline w PWA — nie z Google Fonts).
- Tokeny kolorów dokładnie jak w tabeli w specu (sekcja „Kolory (tokeny)”); motywy nazywają się `light` (domyślny) i `dark` (`--prefersdark`).
- `theme_color` = `#141A33` (manifest w `vite.config.js` i `<meta name="theme-color">` w `index.html`).
- Bez etykiet `uppercase tracking-wide` w całym `web/src` po zakończeniu.
- Liczby po polsku: procenty „+26,85%”, ilości „9,7636” (`Intl.NumberFormat("pl-PL")`).
- Wykres nie jest dzielony na dwa.
- Nie tracimy żadnej istniejącej akcji: dodaj transakcję, usuń transakcję, zmiana nazwy, rozwijanie transakcji, link Yahoo/Giełda, Odśwież ceny, Wygeneruj snapshot, Uzupełnij historię, Import XTB, Nowy portfel, auto-odświeżanie, motyw, pull-to-refresh.
- Copy po polsku, zdaniowo, bez „→” i bez kropek-separatorów „·” w nowych miejscach.

## Review Focus

1. **Pozycja bez wyceny** (`market_value_pln`/`pnl_pln` = null): udział „—” bez paska, P/L „—”, suma udziałów pozostałych pozycji liczona tylko z wycenionych; ostrzeżenie `incomplete` pod hero nadal widoczne. → testy w Task 2 (`shares`) i Task 4 (`Hero`).
2. **Strata** (ujemne P/L): na hero kolor straty czytelny na granacie (`#FF8A8F`), w wierszach `text-error`; znak „−”/„-” poprawny w procencie. → testy w Task 2 (`percent`) i Task 4 (`Hero`).
3. **Pusty portfel / brak portfeli** (suma 0): brak dzielenia przez zero, hero pokazuje „0,00 zł” i pusty procent, lista pusta bez błędu. → test w Task 2 (`shares` z sumą 0) i Task 4.
4. **Długa nazwa instrumentu na 390px** („Vanguard LifeStrategy 80% Equity UCITS ETF (EUR) Accumulating”): zawija się/obcina w kolumnie nazwy, nie wypycha P/L poza ekran. → weryfikacja wizualna w Task 5 (zrzut 390px), plus fallback na symbol przy braku nazwy (test w Task 2 `displayName`).
5. **Motyw przy starcie bez otwierania menu** (zapisany `dark` lub `auto` + systemowy ciemny): `data-theme` ustawiony zanim cokolwiek się wyrenderuje, wykres dostaje ciemne kolory po `hajsomat:themechange`. → testy w Task 3 (`initTheme`) i Task 7 (`buildChartOptions` z `dark: true`).

---

### Task 1: Tokeny Automat + font

**Files:**
- Modify: `web/src/app.css`, `web/src/main.js`, `web/index.html`, `web/vite.config.js` (manifest `theme_color`, `background_color: "#F3F4F8"`), `web/package.json` (+ lockfile)

**Interfaces:**
- Produces: klasy daisyUI (`bg-base-100/200/300`, `text-base-content`, `bg-neutral text-neutral-content`, `btn-primary`, `text-accent`, `bg-accent`, `text-success`, `text-error`) z wartościami ze specu; font Bricolage Grotesque jako domyślny `font-sans`; CSS custom property `--hero-loss: #FF8A8F` w `:root` (używana w Task 4).

- [ ] **Step 1:** Dodaj zależność: `docker run --rm -v "$PWD":/app -w /app node:22-alpine npm install @fontsource-variable/bricolage-grotesque --no-audit --no-fund`, potem `docker compose build web`.
- [ ] **Step 2:** W `main.js` zaimportuj `@fontsource-variable/bricolage-grotesque` przed `./app.css`. W `app.css` ustaw `@theme { --font-sans: "Bricolage Grotesque Variable", ui-sans-serif, system-ui, sans-serif; }`.
- [ ] **Step 3:** W `app.css` zmień `@plugin "daisyui" { themes: ... }` tak, by używał własnych motywów: dwa bloki `@plugin "daisyui/theme" { name: "light"; default: true; ... }` i `{ name: "dark"; prefersdark: true; color-scheme: dark; ... }` z kolorami z tabeli w specu (base-100/200/300, base-content, neutral, neutral-content, primary, primary-content, accent, accent-content `#141A33`, success, error). Drugorzędny tekst: dodaj `--color-muted` (`#646B85` / `#A7AEC9`) przez `@theme` + nadpisanie w `[data-theme=dark]` i `@media (prefers-color-scheme: dark) :root:not([data-theme=light])`, tak żeby działała klasa `text-muted`.
- [ ] **Step 4:** `theme_color` `#141A33` w `index.html` i manifeście.
- [ ] **Step 5: Weryfikacja.** `docker compose run --rm --no-deps web sh -c "npx vitest run && npm run check && npm run build"` → wszystko przechodzi. Uruchom `docker compose up -d --build -V web`, zrób zrzut `http://lvh.me:5173/#/portfolio/2` (Playwright, 390px i 1280px, jasny i ciemny): font Bricolage widoczny, przyciski primary granatowe (jasny) / złote (ciemny). Sprawdź kwotę „65 978,50 zł” w `RollingNumber`: jeśli separatory są za szerokie, usuń klasę `tabular-nums` z kontenera `.rolling` w `RollingNumber.svelte` (spec, „Typografia”).
- [ ] **Step 6: Commit** `git add web/ && git commit -m "Add Automat theme tokens and Bricolage Grotesque font"`

### Task 2: Formaty liczb i udziały

**Files:**
- Modify: `web/src/lib/format.js`, `web/src/lib/format.test.js`
- Create: `web/src/lib/allocation.js`, `web/src/lib/allocation.test.js`

**Interfaces:**
- Produces:
  - `percent(pnl, cost): string` — jak dziś, ale polski format: `"+25,00%"`, `"-5,00%"`, `""` dla kosztu 0 lub P/L null/undefined/"".
  - `quantity(value): string` — `"9,7636"`, do 6 miejsc po przecinku, bez zbędnych zer (`"18,143"`, `"4,7868"`); `"—"` dla null.
  - `sharePercent(share): string` — `0.478` → `"47,8%"` (1 miejsce), `null` → `"—"`.
  - `nextIn(ms): string` — `"za chwilę"` (< 60 s), `"za 42 min"`, `"za 1 h 5 min"`, `"za 2 h"`; od 24 h: `"za 1 dzień"` / `"za N dni"` (pełne dni, np. weekend); `null` → `""`.
  - `shares(items, valueOf): Map<item, number|null>` w `allocation.js` — udział = wartość / suma wartości wycenionych; `null` dla pozycji bez wartości; wszystkie `null` gdy suma 0.
  - `byValueDesc(items, valueOf): items[]` — sortuje malejąco, pozycje bez wartości na końcu (stabilnie).
  - `displayName(pos): string` — `pos.name` jeśli niepusta, inaczej `pos.symbol`.

- [ ] **Step 1: Testy (czerwone).** W `format.test.js` zmień oczekiwania `percent` na `"+25,00%"` i `"-5,00%"`; dodaj:

```js
expect(quantity("9.7636")).toBe("9,7636");
expect(quantity("18.143")).toBe("18,143");
expect(quantity(null)).toBe("—");
expect(sharePercent(0.478)).toBe("47,8%");
expect(sharePercent(null)).toBe("—");
expect(nextIn(30_000)).toBe("za chwilę");
expect(nextIn(42 * 60_000)).toBe("za 42 min");
expect(nextIn(65 * 60_000)).toBe("za 1 h 5 min");
expect(nextIn(120 * 60_000)).toBe("za 2 h");
expect(nextIn(26 * 3_600_000)).toBe("za 1 dzień");
expect(nextIn(50 * 3_600_000)).toBe("za 2 dni");
```

W `allocation.test.js`:

```js
const a = { v: "300" }, b = { v: "100" }, c = { v: null };
const s = shares([a, b, c], (x) => x.v);
expect(s.get(a)).toBeCloseTo(0.75); expect(s.get(b)).toBeCloseTo(0.25); expect(s.get(c)).toBeNull();
const z = { v: "0" };
expect(shares([z], (x) => x.v).get(z)).toBeNull(); // suma 0 → null, bez NaN/Infinity
expect(byValueDesc([b, c, a], (x) => x.v)).toEqual([a, b, c]);
expect(displayName({ name: "", symbol: "SXR8.DE" })).toBe("SXR8.DE");
expect(displayName({ name: "iShares Core S&P 500", symbol: "SXR8.DE" })).toBe("iShares Core S&P 500");
```

- [ ] **Step 2:** `docker compose run --rm --no-deps web npx vitest run` → FAIL (brak funkcji / stary format).
- [ ] **Step 3:** Zaimplementuj w `format.js` (`Intl.NumberFormat("pl-PL", …)`; znak „+” dla dodatnich ręcznie lub `signDisplay: "exceptZero"`) i `allocation.js`. Uwaga: `Intl` w pl-PL wstawia twardą spację w tysiącach — testy powyżej nie mają tysięcy, w razie potrzeby porównuj po `.replace(/\s/g, " ")`.
- [ ] **Step 4:** Testy → PASS. Istniejące użycia `percent()` w `PortfolioList.svelte`/`PortfolioView.svelte` działają bez zmian w wywołaniach.
- [ ] **Step 5: Commit** `"Polish number formats and allocation helpers"`

### Task 3: Moduł motywu

**Files:**
- Create: `web/src/lib/theme.svelte.js`, `web/src/lib/theme.test.js`
- Modify: `web/src/lib/components/ThemeSwitch.svelte`, `web/src/main.js`

**Interfaces:**
- Produces:
  - `THEME_MODES = [{ id: "light", label: "Dzień" }, { id: "auto", label: "Auto" }, { id: "dark", label: "Noc" }]`
  - `theme` — obiekt z getterem `theme.mode` (`"light"|"auto"|"dark"`, reaktywny `$state`).
  - `setTheme(mode)` — zapisuje `localStorage["hajsomat:theme"]`, ustawia/usuwa `document.documentElement.dataset.theme` (auto = brak atrybutu), wysyła `window` event `hajsomat:themechange` z `detail: { mode }`.
  - `initTheme()` — czyta zapisany tryb (nieznany/brak → `"auto"`) i wywołuje `setTheme`. Wołane w `main.js` przed `mount`.
- `ThemeSwitch.svelte` korzysta z modułu (bez własnego `onMount`/localStorage); wygląd segmentów bez zmian. Ikony trzyma komponent.

- [ ] **Step 1: Testy (czerwone)** w `theme.test.js` (jsdom): po `localStorage.setItem("hajsomat:theme","dark"); initTheme()` → `document.documentElement.dataset.theme === "dark"` i `theme.mode === "dark"`; `setTheme("auto")` → brak atrybutu `data-theme`, `localStorage` = `"auto"`, listener `hajsomat:themechange` wywołany z `detail.mode === "auto"`; `localStorage` z wartością `"bogus"` → `initTheme()` daje `"auto"`; wyjątek z `localStorage.getItem` (zamockowany) → `"auto"` bez rzucania.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Zaimplementuj moduł, przepnij `ThemeSwitch.svelte`, dodaj `initTheme()` w `main.js`.
- [ ] **Step 4:** Run → PASS; `npm run check` → 0 błędów.
- [ ] **Step 5: Commit** `"Extract theme state into a module initialised at startup"`

### Task 4: Komponenty Hero, ShareBar, SettingsMenu

**Files:**
- Create: `web/src/lib/components/Hero.svelte`, `web/src/lib/components/ShareBar.svelte`, `web/src/lib/components/SettingsMenu.svelte`, `web/src/lib/components/Hero.test.js`
- Modify: `web/src/lib/components/Countdown.svelte`

**Interfaces:**
- Consumes: `money`, `percent`, `nextIn` (Task 2); `THEME_MODES`, `theme`, `setTheme` (Task 3); `RollingNumber`, `RefreshIntervalSelect`, `ThemeSwitch`.
- Produces:
  - `<Hero value pnl cost updatedAt? incomplete? top? extra?>` — `value/pnl/cost`: liczby lub stringi z API; `top`: snippet górnego wiersza (nazwa/edycja/„← Portfele”); `extra`: snippet dodatkowej linii (np. P/L w zakresie). Renderuje: duża wartość (`RollingNumber`), linia P/L „+X zł  +Y%” (klasa `text-accent` przy pnl ≥ 0, styl `color: var(--hero-loss)` przy < 0), „Wpłacono {money(cost)}”, po prawej w górnym wierszu „zaktualizowano HH:MM” + `<Countdown compact />`. `bg-neutral text-neutral-content`, na telefonie od krawędzi do krawędzi z zaokrąglonymi dolnymi rogami, od `sm` karta z pełnym zaokrągleniem; w ciemnym motywie obramowanie `border-base-300`.
  - `<ShareBar share>` — `share` 0..1 lub null; null → nic nie renderuje; pasek `h-1 rounded-full bg-base-300` z wypełnieniem `bg-accent` o szerokości `share*100%`.
  - `<SettingsMenu actions>` — `actions: { label, onclick, disabled?, title? }[]`; zębatka (`btn btn-ghost btn-square`) z dropdownem: lista akcji, `RefreshIntervalSelect`, `ThemeSwitch`. Tylko desktop (`hidden sm:inline-flex`).
  - `Countdown` dostaje prop `compact` (domyślnie false): w trybie compact renderuje sam tekst `"następne " + nextIn(remaining)` bez ikony i etykiety; tryb domyślny bez zmian.

- [ ] **Step 1: Testy (czerwone)** w `Hero.test.js` (`@testing-library/svelte`, zamockuj `api.schedule` żeby `Countdown` nie robił fetch): render z `value="65978.5" pnl="13967.42" cost="52011.08"` → tekst zawiera „65 978,50 zł”, „+26,85%”, „Wpłacono 52 011,08 zł” (porównuj po normalizacji spacji), element P/L ma klasę `text-accent`; z `pnl="-100" cost="1000"` → „-10,00%” i brak `text-accent`; z `value="0" pnl="0" cost="0"` → „0,00 zł”, bez „NaN”/„Infinity”; z `incomplete` → widoczny komunikat „Część pozycji nie ma aktualnej wyceny”.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Zaimplementuj trzy komponenty i `compact` w `Countdown`.
- [ ] **Step 4:** Run → PASS; `npm run check` → 0 błędów.
- [ ] **Step 5: Commit** `"Add Hero, ShareBar and SettingsMenu components"`

### Task 5: Widok portfela

**Files:**
- Modify: `web/src/lib/components/PortfolioView.svelte`, `web/src/App.svelte`

**Interfaces:**
- Consumes: `Hero`, `ShareBar`, `SettingsMenu` (Task 4); `quantity`, `sharePercent`, `shares`, `byValueDesc`, `displayName`, `percent`, `money` (Task 2).

- [ ] **Step 1:** Zastąp kartę nagłówka + 3 kafelki przez `<Hero>`: w `top` „← Portfele” (tylko `sm`, wywołuje `onBack`), nazwa portfela z ołówkiem i istniejącą edycją nazwy. Ostrzeżenie `incomplete` przez prop Hero.
- [ ] **Step 2:** Pasek akcji (tylko `sm`): `btn btn-primary` „Dodaj transakcję” + `<SettingsMenu actions={[Odśwież ceny (disabled poza sesją, z dotychczasowym title), Uzupełnij historię, Importuj raport XTB]}>`. Usuń rząd z `RefreshIntervalSelect` + `Countdown` (countdown jest teraz w Hero).
- [ ] **Step 3:** Tabelka: wiersze w kolejności `byValueDesc(data.positions, p => p.market_value_pln)`; kolumna nazwy = `displayName(pos)` (zawijanie, `min-w-0`), pod nią `text-muted text-xs`: symbol + link zewnętrzny + `sharePercent(share)`, pod tym `<ShareBar>`; kolumny `sm`: Ilość (`quantity`), Śr. cena, Cena, Wartość (PLN); ostatnia kolumna P/L: `money(pnl)` nad `percent(...)`, kolorowy tekst (`text-success`/`text-error`), bez pigułek. Usuń kolumnę „Zwrot”, zaktualizuj `colspan` (6) i szkielet ładowania (6 kolumn). W rozwinięciu: ilości przez `quantity`, etykiety bez `uppercase tracking-wide`.
- [ ] **Step 4:** `App.svelte`: usuń oba renderowania `ThemeSwitch` (motyw jest w `SettingsMenu`; na telefonie w Task 9).
- [ ] **Step 5: Weryfikacja.** vitest + check przechodzą. Zrzuty Playwright `#/portfolio/2` na 390px i 1280px, jasny i ciemny: zgodność z makietą (`docs/superpowers/specs/2026-11-03-redesign-automat-mockup.html`), długa nazwa V80A nie wypycha P/L, rozwijanie transakcji i usuwanie działają, edycja nazwy działa.
- [ ] **Step 6: Commit** `"Redesign portfolio view with Automat hero and allocation table"`

### Task 6: Lista portfeli

**Files:**
- Modify: `web/src/lib/components/PortfolioList.svelte`

**Interfaces:**
- Consumes: `Hero`, `ShareBar`, `SettingsMenu`, `shares`, `byValueDesc`, `sharePercent`, `percent`, `money`.

- [ ] **Step 1:** Nagłówek `sm`: „Moje portfele” + `btn btn-primary` „Nowy portfel” + `<SettingsMenu actions={[Odśwież ceny (poza sesją disabled), Wygeneruj snapshot]}>`; usuń rząd z `RefreshIntervalSelect` + `Countdown`.
- [ ] **Step 2:** `<Hero value={totals.value} pnl={totals.pnl} cost={totals.cost} updatedAt={lastUpdated}>` z `extra`: „W zakresie {rangeSummary.label}: {money(rangeSummary.pnl)}” w kolorze zysku/straty (tylko gdy zakres ≠ „całość” i `rangeSummary` istnieje). Usuń kartę „Razem” z kafelkami i nagłówek „Łącznie — wszystkie portfele”. Hero nad listą.
- [ ] **Step 3:** Wiersze portfeli (kolejność `byValueDesc` po `market_value_pln`): nazwa, pod nią `sharePercent` udziału w sumie + `ShareBar`; po prawej wartość, pod nią P/L i % kolorowym tekstem (bez pigułki i bez „·”); gwiazdka `incomplete` zostaje. Bez ikony portfela i podpisu „Portfel”. Szkielet ładowania dopasowany. Modal „Nowy portfel”: etykieta bez `uppercase tracking-wide`.
- [ ] **Step 4: Weryfikacja.** vitest + check; zrzuty `#/` 390px/1280px, jasny/ciemny; przejście do portfela działa.
- [ ] **Step 5: Commit** `"Redesign portfolio list with combined hero"`

### Task 7: Opcje wykresu (logika)

**Files:**
- Create: `web/src/lib/chartOptions.js`, `web/src/lib/chartOptions.test.js`
- Modify: `web/src/lib/components/PortfolioChart.svelte`

**Interfaces:**
- Produces: `buildChartOptions(snaps, { palette, dark, compact }): ApexOptions` — przeniesione z `PortfolioChart.svelte` (`series`, `xaxis`, `tooltip`, `options`), plus `seriesColors(palette, dark): string[]` i `chartPalette()` czytające `--color-*` motywu. `PortfolioChart.svelte` tylko woła te funkcje (efekty, zoom, legenda zapamiętywana — bez zmian zachowania). `compact` = szerokość kontenera < 640px (mierzona w komponencie).
- Wartości: seria Wartość = `#141A33` (jasny) / `#C9D1F0` (ciemny), Wpłaty = `#F2B705` przerywana, Zysk = kolor `success`, słupki = success/error. `fill.gradient.type = "vertical"`, gradient w kolorze serii (`gradientToColors` = kolor serii, `opacityFrom 0.35 → opacityTo 0`). Legenda: `position: "top"`, `horizontalAlign: "left"`, kompaktowe markery. `compact`: osie Y bez `title`, `xaxis.labels.rotate = 0` i `hideOverlappingLabels: true`, `tickAmount` ≤ 4, prawa oś z formaterem skróconym (`1500` → „1,5k”).

- [ ] **Step 1: Testy (czerwone)** w `chartOptions.test.js` (snaps: 3 punkty z `date/total_value_pln/total_cost_pln/pnl_pln`): `buildChartOptions(snaps, {palette, dark:false, compact:false}).fill.gradient.type === "vertical"`; `colors[0] === "#141A33"`, a z `dark:true` → `"#C9D1F0"`; `compact:true` → każdy `yaxis[i].title?.text` jest pusty/undefined, `xaxis.labels.rotate === 0`; formater prawej osi w compact: `1500` → `"1,5k"`; `series` ma 5 serii w kolejności Wartość, Wpłaty, Zysk, Zmiana rynkowa, Wpłata (dzienna) (nazwy bez zmian, bo zapamiętane ukryte serie są po nazwach).
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Przenieś i zmień logikę; komponent mierzy szerokość (`ResizeObserver`) i przekazuje `compact`; przy zmianie `compact` lub motywu → `updateOptions`.
- [ ] **Step 4:** Run → PASS; check → 0 błędów.
- [ ] **Step 5: Commit** `"Move chart options to a tested module with Automat colours"`

### Task 8: Karta wykresu (sterowanie)

**Files:**
- Modify: `web/src/lib/components/ChartPanel.svelte`, `web/src/lib/chartRange.js` (tylko jeśli potrzebna etykieta)

- [ ] **Step 1:** Cały panel w jednej karcie (`bg-base-100 rounded-box border border-base-300`). Nagłówek w jednym wierszu: segmenty `1M 3M 6M YTD Rok▾ Całość` (zastąp ikonę ↔ słowem „Całość”, ten sam `data-segment="all"`) + po prawej rozdzielczość jako `<select class="select select-xs">` z opcjami `RESOLUTIONS` (etykiety „Dzień/Tydzień/…”). Usuń napisy „Zakres”/„Rozdzielczość” i drugi rząd.
- [ ] **Step 2:** Segmenty nie zawijają się: kontener `flex-nowrap overflow-x-auto` (bez widocznego paska przewijania); menu lat działa (dropdown nie jest przycinany przez `overflow` — jeśli jest, renderuj listę lat poza przewijanym kontenerem). Thumb (`thumbStyle`) dalej liczony względem grupy.
- [ ] **Step 3: Weryfikacja.** vitest + check; zrzuty 390px (wszystkie segmenty w jednym wierszu, brak pustego pola), 1280px; przełączenie zakresu, roku i rozdzielczości działa i jest zapamiętywane po przeładowaniu; na liście portfeli linia „W zakresie …” w Hero aktualizuje się (`onRangeChange`).
- [ ] **Step 4: Commit** `"Put range and resolution controls in the chart card header"`

### Task 9: Pasek mobilny, modale i porządki

**Files:**
- Modify: `web/src/lib/components/MobileNav.svelte`, `web/src/lib/components/PortfolioView.svelte`, `web/src/lib/components/PortfolioList.svelte`, `web/src/lib/components/TransactionForm.svelte`, `web/src/lib/components/Modal.svelte`

**Interfaces:**
- Consumes: `THEME_MODES`, `theme`, `setTheme` (Task 3).

- [ ] **Step 1:** `MobileNav`: struktura bez zmian (wdrożony układ przyklejony do dołu). Wygląd: przycisk zwinięty `bg-neutral text-accent` z ikoną (zamiast szarego favicona), rozwinięty pasek `bg-base-100/90` z obramowaniem `border-base-300`, aktywna pozycja/otwarte podmenu `text-primary` (w ciemnym = złoto).
- [ ] **Step 2:** Pozycja „Więcej” w obu widokach. Widok portfela: do istniejącego podmenu dodaj 3 pozycje motywu z `THEME_MODES` (`label: "Motyw: Dzień"` itd., `active: theme.mode === id`, `keepOpen: true`, `onclick: () => setTheme(id)`). Lista portfeli: nowa pozycja „Więcej” (ikona `more-horizontal`) z podmenu: „Wygeneruj snapshot” + 3 pozycje motywu; dotychczasowa pozycja „Snapshot” w pasku znika (zostają: Nowy, Ceny, Auto, Więcej).
- [ ] **Step 3:** `TransactionForm`: przycisk `btn-success` → `btn-primary`; etykiety bez `uppercase tracking-wide` (zdaniowo, `text-muted text-sm`). To samo w modalu importu w `PortfolioView`. `Modal`: tło `bg-base-100`, bez zmian zachowania.
- [ ] **Step 4:** `grep -rn "uppercase tracking-wide\|btn-success" web/src` → brak wyników.
- [ ] **Step 5: Weryfikacja.** vitest + check + build; zrzuty 390px jasny/ciemny: zwinięty i rozwinięty pasek, podmenu „Więcej” z motywem (przełączenie motywu działa i zmienia kolory wykresu), modal dodawania transakcji.
- [ ] **Step 6: Commit** `"Restyle mobile nav and forms, move theme switch into Więcej"`

### Task 10: Weryfikacja końcowa

- [ ] **Step 1:** `docker compose run --rm --no-deps web sh -c "npx vitest run && npm run check && npm run build"` → wszystko zielone.
- [ ] **Step 2:** Przejdź listę „nie tracimy żadnej akcji” z Global Constraints w przeglądarce (Playwright, 390px i 1280px): każda akcja dostępna i działa.
- [ ] **Step 3:** Zrzuty końcowe obu widoków × 2 szerokości × 2 motywy; porównanie z makietą. Usuń `.playwright-mcp/` z repo.
