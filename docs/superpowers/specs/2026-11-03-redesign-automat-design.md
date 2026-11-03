# Redesign „Automat” — design

Data: 2026-11-03 · Status: zatwierdzony kierunek (wariant C z makiet)

## Po co

hajsomat działa, ale wygląda jak domyślny zestaw daisyUI: domyślny fiolet, systemowy font, wszystko w
identycznych zaokrąglonych kartach z etykietami WIELKIMI LITERAMI. Do tego kilka konkretnych usterek
(mieszane formaty liczb, nieczytelny wykres na telefonie). Użytkownik chce, żeby aplikacja wyglądała
nowocześniej i miała własny charakter — i wybrał z trzech makiet wariant **C „Automat”**: granat + złoto,
font z charakterem, wyraźnie „hajsomat”.

Najważniejsze pytanie, na które ekran ma odpowiadać od razu: **ile mam i ile zarobiłem** (kwotowo i %),
a zaraz potem: **co mam i ile tego jest** (udział pozycji w portfelu).

## Cele

1. Własna tożsamość wizualna „Automat” w obu trybach (jasny / ciemny).
2. Hierarchia: jedna duża liczba na ekran zamiast trzech równorzędnych kafelków.
3. Czytelniejsza tabelka pozycji: nazwy instrumentów, udział w portfelu, P/L + zwrot razem.
4. Uporządkowany wykres (bez dzielenia go) i jego sterowanie.
5. Mniej „szumu” narzędziowego wokół treści.
6. Usunięcie znanych usterek wizualnych.

## Nie-cele

- **Nie dzielimy wykresu** na dwa (wartość + osobny pasek zmian dziennych) — użytkownik wprost odrzucił.
- Żadnych zmian w backendzie, API, logice wyceny ani w danych. To czysto frontend (`web/`).
- Bez nowych funkcji (wykresy per instrument, porównanie z indeksami itp.).
- Nie zmieniamy routingu, PWA (poza kolorem motywu w manifeście) ani WebSocketów.

## Anty-cele (porażka, nawet jeśli „działa”)

- Pogorszenie czytelności liczb (np. szerokie przecinki z cyfr tabelarycznych — patrz „Typografia”).
- Wolniejsze ładowanie / brak fontu offline w PWA (font musi być lokalny, nie z Google Fonts).
- Utrata funkcji, które dziś są dostępne (każda akcja z menu, rozwijanie transakcji, linki do Yahoo/Giełdy,
  pull-to-refresh, przełącznik motywu, auto-odświeżanie, import XTB, usuwanie transakcji, zmiana nazwy).
- Zepsuty tryb ciemny lub mobile.

## Tożsamość „Automat”

### Kolory (tokeny)

Własne motywy daisyUI zamiast `light`/`dark` (w `web/src/app.css`, `@plugin "daisyui/theme"`), tak żeby
istniejące klasy (`bg-base-100`, `text-success`, `btn-primary`…) dalej działały.

| Token daisyUI / rola | Jasny | Ciemny |
|---|---|---|
| `base-200` — tło strony | `#F3F4F8` | `#0F1428` |
| `base-100` — karty | `#FFFFFF` | `#1B2242` |
| `base-300` — linie, tor paska udziału | `#E4E6EF` | `#2A3256` |
| `base-content` — tekst główny | `#141A33` | `#E8EAF4` |
| tekst drugorzędny (`base-content` z kryciem lub własna klasa) | `#646B85` | `#A7AEC9` |
| `neutral` — tło hero | `#141A33` | `#1B2242` (= karta, z obramowaniem `#2A3256`) |
| `neutral-content` — tekst na hero | `#FFFFFF` | `#FFFFFF` |
| `primary` / `primary-content` | `#141A33` / `#F2B705` | `#F2B705` / `#141A33` |
| `accent` — złoto (pasek udziału, Wpłaty, P/L na hero) | `#F2B705` | `#F2B705` |
| `success` — zysk | `#148A55` | `#2FBF7A` |
| `error` — strata | `#CC3D45` | `#F0646C` |

- Hero zawsze używa `bg-neutral text-neutral-content`; P/L na hero przy zysku w `accent` (złoto), przy
  stracie w jasnym odcieniu straty czytelnym na granacie (np. `#FF8A8F`).
- W ciemnym trybie granat `#141A33` nie jest używany jako tło (tło strony jest ciemniejsze, `#0F1428`);
  primary = złoto z granatowym tekstem, bo granat na granacie byłby niewidoczny.
- Ciemne wartości zysku/straty i tekstu drugorzędnego to propozycja — builder ma sprawdzić kontrast
  (WCAG AA dla tekstu) i skorygować odcień, nie zmieniając charakteru.
- `theme_color` w manifeście PWA: `#141A33` (dziś `#863bff`).
- Kolory serii wykresu: Wartość = granat (w ciemnym trybie jasny niebieskoszary, np. `#C9D1F0`),
  Wpłaty = złoto (przerywana), Zysk = zysk/teal; słupki zmian dziennych = success/error.

### Typografia

- **Bricolage Grotesque**, self-hosted z npm (`@fontsource-variable/bricolage-grotesque`), żeby działał
  offline w PWA (precache Workboxa). Jedna rodzina na całą aplikację.
- **Uwaga na cyfry tabelaryczne**: dziś `body` ma `font-variant-numeric: tabular-nums`. W makiecie
  Schibsted Grotesk z `tabular-nums` dawał szerokie odstępy wokół przecinka. Builder ma sprawdzić, jak
  Bricolage wygląda z `tabular-nums` w kwotach („65 978,50 zł”).
- **`RollingNumber` zostaje (z animacją) wszędzie, także w hero.** Cyfry i tak siedzą w slotach o
  szerokości „0”, więc są stałej szerokości niezależnie od `font-variant-numeric` — to akceptujemy.
  Jeśli separatory (spacja, przecinek, „zł”) wyglądają za szeroko, usuwamy klasę `tabular-nums`
  z kontenera `.rolling` (separatory to zwykły tekst, sloty cyfr dalej trzymają szerokość). Nie
  przepisujemy `RollingNumber` na sloty per cyfra.
- Bez etykiet WIELKIMI LITERAMI (`uppercase tracking-wide`) — zamieniamy na zwykły tekst zdaniowy
  w kolorze drugorzędnym.
- Duża liczba w hero: ~40px na telefonie, większa na desktopie, waga 800, lekko ujemny letter-spacing.

## Widoki

Referencja wizualna: makieta wariantu C (telefon 390px, portfel IKE) —
[`2026-11-03-redesign-automat-mockup.html`](2026-11-03-redesign-automat-mockup.html) (otwórz w przeglądarce).
Poniżej to, co z niej wynika, plus decyzje dla miejsc, których makieta nie pokazywała (oznaczone
„decyzja projektowa”).

**Kolejność sekcji** (oba widoki, telefon i desktop): hero → (pasek akcji, tylko desktop) → wiersze
(pozycje / portfele) → karta wykresu. Tak jak dziś: wykres pod listą.

**Desktop (decyzja projektowa):** treść dalej w kolumnie `max-w-4xl`. Hero to karta w tej kolumnie
z zaokrągleniem na wszystkich rogach (na telefonie: od krawędzi do krawędzi, zaokrąglone tylko dolne
rogi, jak w makiecie). Przycisk powrotu „Portfele” na desktopie przenosimy do górnego wiersza hero,
przed nazwę portfela (strzałka + „Portfele”), zamiast osobnego obramowanego przycisku nad kartą.

### Widok portfela (`PortfolioView.svelte`)

**Hero (granatowy blok u góry, zaokrąglone dolne rogi):**
- wiersz: nazwa portfela (z ołówkiem do zmiany nazwy) + po prawej „zaktualizowano HH:MM”;
- duża wartość portfela;
- pod nią jedna linia na złoto: „+13 967,42 zł  +26,85%” (przy stracie — kolor straty, czytelny na
  granacie);
- niżej drugorzędnie „Wpłacono 52 011,08 zł”;
- zastępuje dzisiejszą kartę z ikoną portfela i trzema kafelkami. Ostrzeżenie `incomplete` zostaje,
  pod hero.
- W ciemnym trybie hero to karta o ton jaśniejsza od tła (decyzja projektowa), żeby nie zlewała się z tłem.

**Tabelka pozycji:**
- pierwsza kolumna: pełna nazwa instrumentu (`pos.name`, fallback do symbolu, gdy brak nazwy) jako tekst
  główny; pod nią drugorzędnie ticker i udział w portfelu („SXR8.DE   47,8%”); pod spodem cienki złoty
  pasek udziału (szerokość = udział);
- udział = `market_value_pln` pozycji / suma `market_value_pln` portfela; gdy brak wyceny — brak paska
  i „—”; liczony na froncie;
- kolumna P/L: kwota nad procentem, kolorowy tekst (bez „pigułek”), wyrównane do prawej;
- **desktop (decyzja projektowa):** zostają kolumny Ilość, Śr. cena, Cena, Wartość (PLN) między nazwą
  a P/L; kolumna „Zwrot” znika (procent jest pod kwotą P/L);
- telefon: tylko nazwa + P/L, jak w makiecie;
- rozwijanie wiersza z transakcjami, link zewnętrzny (Yahoo / Giełda) i usuwanie transakcji działają jak
  dziś; link przenosimy obok tickera;
- kolejność wierszy: malejąco po wartości (decyzja projektowa; dziś kolejność z API).

**Akcje:** dzisiejsza osobna karta z „Dodaj transakcję” + zębatką na desktopie zostaje zastąpiona
mniejszym paskiem akcji (przycisk primary + menu). Kolor głównego przycisku taki sam jak na liście
portfeli (primary).

### Lista portfeli (`PortfolioList.svelte`) — decyzja projektowa

- Ten sam granatowy hero na górze: łączna wartość wszystkich portfeli, P/L i zwrot, „Wpłacono …”.
  Dzisiejszy kafelek „Zakres: 3M” (P/L w wybranym zakresie) zostaje jako drugorzędna linia w hero:
  „W zakresie 3M: +5 174,79 zł”.
- Portfele jako wiersze w stylu pozycji: nazwa, pod nią udział w sumie wszystkich portfeli ze złotym
  paskiem; po prawej wartość, a pod nią P/L + % w kolorze. Klik → widok portfela (jak dziś).
- Nagłówek „Moje portfele” + „Nowy portfel” (primary) + menu akcji.
- Usuwamy podpis „Portfel” pod nazwą (nic nie mówi) i ikonę portfela w każdym wierszu.

### Wykres (`ChartPanel.svelte`, `PortfolioChart.svelte`) — bez dzielenia

- Wszystko w jednej karcie. Nagłówek karty w jednym wierszu: segmenty zakresu
  `1M 3M 6M YTD Rok Całość` (Rok nadal z listą lat) + po prawej rozdzielczość jako mała lista
  („Dzień ▾”). Znikają osobne rzędy z napisami „ZAKRES” / „ROZDZIELCZOŚĆ”.
- Segmenty nie mogą się zawijać na telefonie (dziś ↔ spada do drugiego wiersza i zostaje puste pole);
  przy braku miejsca — przewijanie poziome segmentów albo krótsze etykiety, decyzja buildera.
- Ikona ↔ („cały zakres”) zastąpiona słowem „Całość” (decyzja projektowa, czytelniejsze).
- Legenda kompaktowa w jednym wierszu (zawija się tylko jeśli musi), nadal klikalna i zapamiętywana
  (istniejące `loadHiddenSeries`/`saveHiddenSeries`).
- Seria „Wartość”: gradient w kolorze serii, pionowy (od linii w dół do przezroczystości) — dziś to
  szara pozioma smuga.
- Telefon: bez obróconych tytułów osi, daty na osi X bez obracania (mniej etykiet), żeby obszar
  wykresu był szeroki. Druga oś (zł/dzień) może zostać, ale bez tytułu; jej etykiety skrócone (np. „1,5k”).
- Tooltip, zoom kółkiem, zapamiętywanie zakresu/rozdzielczości — bez zmian w zachowaniu.

### Mniej szumu narzędziowego

- **Desktop — jedno menu (decyzja projektowa).** Pasek akcji pod hero to: przycisk primary („Nowy
  portfel” / „Dodaj transakcję”) + jedna zębatka. Pod zębatką: akcje danego widoku (Odśwież ceny,
  Wygeneruj snapshot / Uzupełnij historię, Importuj raport XTB), wybór auto-odświeżania i przełącznik
  motywu (Dzień / Auto / Noc jako jeden wiersz segmentów). To ta sama zębatka, o której mowa w sekcji
  „Akcje” — nie ma drugiego menu. `ThemeSwitch` przestaje być renderowany globalnie w `App.svelte`
  (dziś dwa miejsca: prawy górny róg na desktopie i pod treścią na telefonie); trafia do menu w obu
  widokach. Logika motywu (klucz `hajsomat:theme`, event `hajsomat:themechange`) bez zmian — może
  wymagać wydzielenia jej z komponentu do modułu, żeby inicjalizacja motywu przy starcie nie zależała
  od tego, czy menu jest otwarte.
- **Telefon — `MobileNav` (decyzja projektowa).** Struktura i zachowanie zostają takie, jak właśnie
  wdrożone (zwinięty przycisk → pasek przyklejony do dołu z pozycjami i podmenu). Zmieniamy tylko
  wygląd na tokeny Automat (np. przycisk zwinięty i aktywne pozycje w granacie/złocie zamiast szarej
  ikony i białego szkła). Przełącznik motywu trafia do podmenu „Więcej” w obu widokach; na liście
  portfeli dodajemy pozycję „Więcej” (dziś jej tam nie ma), w której jest przełącznik motywu — ewentualnie
  razem z „Snapshot”, jeśli brakuje miejsca w pasku.
- Odliczanie do odświeżenia jako cicha linia statusu, np. w hero obok „zaktualizowano 09:10”:
  „następne za 42 min” (zastępuje dzisiejszy rząd z selectem i timerem).
- Numer builda w stopce zostaje.

### Porządki / usterki

1. Polskie formaty liczb wszędzie: procenty „+26,85%” (dziś `toFixed` z kropką w `percent()`),
   ilości „9,7636” (dziś surowy string z API). Wspólne helpery w `web/src/lib/format.js`
   (`Intl.NumberFormat("pl-PL")`), z testami.
2. Jeden kolor głównego przycisku (dziś „Nowy portfel” fioletowy, „Dodaj transakcję” zielony).
3. Gradient „Wartości” na wykresie (patrz wyżej).
4. Zawijanie przełącznika zakresu na telefonie (patrz wyżej).
5. Modale (dodaj transakcję, import, nowy portfel) — ten sam język wizualny (font, kolory, bez
   etykiet WIELKIMI LITERAMI); bez zmian w ich działaniu.

## Ograniczenia

- Stack bez zmian: Svelte 5 (runes), Tailwind v4 + daisyUI 5, ApexCharts 7, lucide. Nowa zależność
  tylko na font (`@fontsource-variable/bricolage-grotesque`).
- Wszystko uruchamiane przez Docker Compose; `npm test` (Vitest) i `npm run check` muszą przechodzić.
- Mobile-first: typowy ekran 390px, bezpieczne obszary iOS (`safe-area-inset`), PWA standalone.
- Tryb ciemny przez istniejący `ThemeSwitch` (`data-theme`) i `prefers-color-scheme` — oba muszą działać.
- Wykres reaguje na zmianę motywu (istniejący event `hajsomat:themechange`) — nowe kolory serii też.

## Zostawione builderowi

- Dokładne odstępy, promienie, rozmiary pośrednie fontu (trzymając się makiety C).
- Podział na komponenty (np. wspólny `Hero.svelte` / `PositionRow.svelte` dla listy i widoku portfela).
- Sposób rozwiązania braku miejsca na segmenty zakresu na wąskich ekranach.
- Kolejność wdrażania (sugestia: tokeny + font → format liczb → widok portfela → lista → wykres → szum).
- Weryfikacja wizualna: zrzuty w Playwright na 390px i ~1280px, jasny i ciemny, przed oddaniem.
