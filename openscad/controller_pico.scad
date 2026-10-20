// controller_pico.scad — Controller USB snello in stile pad anni '90: 1 joystick KY-023 + 4 pulsanti 12x12
// Scheda: Raspberry Pi Pico RP2040 (clone TZT con USB-C) - gamepad USB nativo per PC, Recalbox, Raspberry, Android, senza driver.
// Parti: "sopra" (stampato capovolto, piano superiore sul piatto), "sotto" (stampato com'e'), "piastrina" pulsanti.
// Viti: 4 x M3x12 + 2 x M3x8 testa cilindrica (chiusura, da sotto; le M3x8 nelle impugnature), 5 x M3x6 (joystick e piastrina).
// Tutte le misure in mm. Piano di divisione dei due gusci a z = 0.

/* [Parte da generare] */
parte = "assieme"; // [assieme, esploso, sopra, sotto, piastrina]

/* [Guscio] */
H       = 11.5;   // semi-altezza del corpo centrale: piano superiore a +H, fondo a -H (spessore 23 mm)
r_bordo = 11;     // raggio in pianta dei bordi arrotondati
par     = 2.4;    // spessore pareti
gioco   = 0.2;    // gioco tra labbro di centraggio e parete
labbro  = [1.2, 2.5];  // spessore e altezza del labbro (sul guscio sotto)
// apici del corpo centrale (il piano superiore piatto e' il poligono che li unisce)
corpo_pt = [[-46, 20], [0, 22], [46, 20], [56, -2], [24, -24], [-24, -24], [-56, -2]];
// impugnatura destra (la sinistra e' speculare): [x, y, z centro, raggio in pianta, raggio verticale]
// i primi due punti coincidono con gli apici del corpo; gli altri disegnano il "corno" che scende verso il palmo
impugnatura = [[56, -2, 0, r_bordo, H], [24, -24, 0, r_bordo, H], [47, -40, -3, 13, 12.5], [55, -66, -8, 12, 11]];

/* [Joystick KY-023] */
joy       = [-33, 2];    // centro della leva (a sinistra, dove i pad classici hanno la croce)
joy_foro  = 26;          // foro per la cupola del joystick
joy_svasa = 1.2;         // svasatura del foro
joy_fori  = [20.5, 26.5];// interasse fori schedina (x, y) attorno alla leva: MISURARE
joy_alt   = 11.5;        // dal piano della schedina al sotto del piano superiore: MISURARE
joy_pcb   = [26, 34];    // schedina (connettore a 5 pin verso il retro, +y)
joy_col_d = 6.5;         // colonnine

/* [Pulsanti 12x12 + tappo 10x10] */
pul_c       = [33, 1.5]; // centro del rombo A/B/X/Y
pul_passo   = 12;        // distanza dei pulsanti dal centro
tappo_foro  = 10.6;      // foro quadrato per il tappo 10x10
pul_corpo   = 12.4;      // sede del corpo 12x12 sotto il piano
pul_sede    = 0.8;       // profondita' sede
pul_h       = 3.5;       // altezza corpo pulsante
piast_sp    = 2.5;       // spessore piastrina
piast_quadro= 15;        // lato del quadrato attorno a ogni pulsante

/* [Raspberry Pi Pico TZT USB-C] */
pm      = [21.6, 51.6];  // scheda 21 x 51 (larghezza, lunghezza) + gioco
pm_sp   = 1.0;           // spessore PCB: MISURARE (se e' 1,6 metti 1.6)
usb_h   = 3.2;           // altezza della presa USB-C sopra il PCB (3,2 tipica; micro-USB 2,7)
usb_fin = [12.5, 7.5];   // finestra per la spina USB-C (va bene anche per la micro-USB)

/* [Viti di chiusura M3] */
// [x, y, lunghezza vite]: nelle impugnature il guscio e' piu' basso, li' vanno viti M3x8
viti      = [[-18, 26, 12], [18, 26, 12], [-20, -26, 12], [20, -26, 12], [-52, -50, 8], [52, -50, 8]];
vite_boss = 9;
pilota    = 2.5;
passante  = 3.4;
testa_d   = 6.5;
testa_z   = -5;          // fine della sede testa (vite M3x12: 5 mm sotto + 7 mm sopra)

/* [Qualita'] */
$fn     = 48;
fn_corpo= 56;

// ---------------------------------------------------------------- quote derivate
z_cielo = H - par;                    // sotto del piano superiore
z_pcb   = z_cielo - joy_alt;          // faccia superiore della schedina joystick
z_pul   = z_cielo + pul_sede;         // faccia superiore del corpo dei pulsanti
z_piast = z_pul - pul_h;              // faccia superiore della piastrina
pulsanti = [[0, 1], [1, 0], [-1, 0], [0, -1]];   // Y, B, X, A
pm_y1   = 22 + r_bordo - par - 1;     // bordo della scheda lato USB
pm_y0   = pm_y1 - pm[1];
pm_top  = -pm_sp;                     // faccia superiore PCB: centro della presa USB a z = 0 circa
pm_bot  = pm_top - pm_sp;
z_min   = max(concat([for (g = impugnatura) g[4] - g[2]], [H]));

// ---------------------------------------------------------------- forma
module ell(r, rz) scale([r, r, rz]) sphere(1, $fn = fn_corpo);
module ell_g(g, o) translate([g[0], g[1], g[2]]) ell(g[3] - o, g[4] - o);

module corpo(o = 0) {
    hull() for (p = corpo_pt) translate([p[0], p[1], 0]) ell(r_bordo - o, H - o);
    for (s = [-1, 1]) mirror([s < 0 ? 1 : 0, 0, 0]) {
        hull() for (i = [0:2]) ell_g(impugnatura[i], o);                       // attacco al corpo
        for (i = [2:len(impugnatura) - 2]) hull() { ell_g(impugnatura[i], o); ell_g(impugnatura[i + 1], o); }
    }
}

module guscio() difference() { corpo(0); corpo(par); }
module semispazio_sopra() translate([-200, -200, 0]) cube([400, 400, 100]);
module semispazio_sotto() translate([-200, -200, -100]) cube([400, 400, 100]);

module usb_finestra()
    hull() for (i = [-1, 1], k = [-1, 1])
        translate([i * (usb_fin[0] / 2 - 1.5), pm_y1 - 2, k * (usb_fin[1] / 2 - 1.5)]) rotate([-90, 0, 0]) cylinder(r = 1.5, h = 25);

module fori_joy() for (i = [-1, 1], k = [-1, 1]) translate([joy[0] + i * joy_fori[0] / 2, joy[1] + k * joy_fori[1] / 2, 0]) children();
function pul_pos(p) = [pul_c[0] + p[0] * pul_passo, pul_c[1] + p[1] * pul_passo];

// ---------------------------------------------------------------- guscio superiore
module sopra() {
    difference() {
        union() {
            intersection() { guscio(); semispazio_sopra(); }
            intersection() {
                corpo(0);
                union() {
                    fori_joy() translate([0, 0, z_pcb]) cylinder(d = joy_col_d, h = H);
                    translate([pul_c[0], pul_c[1], z_piast]) cylinder(d = 7, h = H);
                    for (v = viti) translate([v[0], v[1], 0]) cylinder(d = vite_boss, h = 2 * H);
                    translate([-4, pm_y1 - 7, pm_top + usb_h + 0.2]) cube([8, 6, 2 * H]);   // pressore sulla presa USB (0,2 di gioco)
                }
            }
        }
        // foro joystick con svasatura
        translate([joy[0], joy[1], z_cielo - 1]) cylinder(d = joy_foro, h = 3 * H, $fn = 96);
        translate([joy[0], joy[1], H - joy_svasa]) cylinder(d1 = joy_foro, d2 = joy_foro + 2 * joy_svasa + 2, h = joy_svasa + 1, $fn = 96);
        // pulsanti: foro tappo + sede corpo + smusso
        for (p = pulsanti) translate([pul_pos(p)[0], pul_pos(p)[1], 0]) {
            translate([-tappo_foro / 2, -tappo_foro / 2, z_cielo - 1]) cube([tappo_foro, tappo_foro, 3 * H]);
            translate([-pul_corpo / 2, -pul_corpo / 2, z_cielo - 1]) cube([pul_corpo, pul_corpo, pul_sede + 1]);
            translate([0, 0, H - 0.6]) linear_extrude(1, scale = 1.25) square(tappo_foro, center = true);
        }
        // fori pilota
        fori_joy() translate([0, 0, z_pcb - 1]) cylinder(d = pilota, h = 7, $fn = 24);
        translate([pul_c[0], pul_c[1], z_piast - 1]) cylinder(d = pilota, h = 5, $fn = 24);
        for (v = viti) translate([v[0], v[1], -1]) cylinder(d = pilota, h = v[2] + testa_z + 2, $fn = 24);
        usb_finestra();
    }
}

// ---------------------------------------------------------------- guscio inferiore
module sotto() {
    difference() {
        union() {
            intersection() { guscio(); semispazio_sotto(); }
            // labbro di centraggio
            difference() {
                intersection() {
                    difference() { corpo(par + gioco); corpo(par + gioco + labbro[0]); }
                    translate([-200, -200, -0.01]) cube([400, 400, labbro[1] + 0.01]);
                }
                for (v = viti) translate([v[0], v[1], -1]) cylinder(d = vite_boss + 1, h = 10);
            }
            intersection() {
                corpo(0);
                union() {
                    for (v = viti) translate([v[0], v[1], -4 * H]) cylinder(d = vite_boss, h = 4 * H);
                    // culla del Pico: listello centrale + due sponde
                    translate([-4, pm_y0 + 2, -4 * H]) cube([8, pm[1] - 4, 4 * H + pm_bot]);
                    for (s = [-1, 1]) translate([s * (pm[0] / 2 + 0.3) + (s < 0 ? -1.6 : 0), pm_y0, -4 * H])
                        cube([1.6, pm[1] - 1, 4 * H + pm_top + 1]);
                }
            }
        }
        for (v = viti) translate([v[0], v[1], 0]) {
            translate([0, 0, -4 * H]) cylinder(d = passante, h = 4 * H + 1, $fn = 24);
            translate([0, 0, -4 * H]) cylinder(d = testa_d, h = 4 * H + testa_z);
        }
        usb_finestra();
    }
}

// ---------------------------------------------------------------- piastrina che tiene i 4 pulsanti (centrata sul rombo)
module piastrina() {
    difference() {
        hull() for (p = pulsanti) translate([p[0] * pul_passo - piast_quadro / 2, p[1] * pul_passo - piast_quadro / 2, 0]) cube([piast_quadro, piast_quadro, piast_sp]);
        translate([0, 0, -1]) cylinder(d = passante, h = piast_sp + 2, $fn = 24);
        for (p = pulsanti) translate([p[0] * pul_passo, p[1] * pul_passo, -1]) {
            for (s = [-1, 1]) translate([s * 6.25 - 1.5, -4.5, 0]) cube([3, 9, piast_sp + 2]);   // zampette passo 12,5
            translate([-3, -3, 0]) cube([6, 6, piast_sp + 2]);                                   // passaggio fili
        }
    }
}

// ---------------------------------------------------------------- componenti colorati (solo immagini della guida)
col_sopra = "#2b3440"; col_sotto = "#9aa3ad"; col_piast = "#e8590c";
col_tappi = ["#eab308", "#dc2626", "#2563eb", "#16a34a"];   // Y giallo, B rosso, X blu, A verde (come pulsanti[])

module ky023(leva = true) {
    color("#1d4ed8") translate([-joy_pcb[0] / 2, -joy_pcb[1] / 2, -1.6]) cube([joy_pcb[0], joy_pcb[1], 1.6]);
    color("#c7cbd1") translate([-8, -8, 0]) cube([16, 16, joy_alt - 1.5]);
    color("#3a3f45") translate([0, 0, joy_alt - 1.5]) cylinder(d = 15, h = 1.5);
    if (leva) {
        color("#2d2d2d") cylinder(d = 4, h = joy_alt + 13);
        color("#262a2e") translate([0, 0, joy_alt + 11]) difference() {
            cylinder(d = 22, h = 7, $fn = 64);
            translate([0, 0, 13]) sphere(d = 22, $fn = 64);
        }
    }
    color("#d4a017") for (i = [0:4]) translate([-5.08 + i * 2.54 - 0.32, joy_pcb[1] / 2 - 2, -0.9]) cube([0.64, 5, 0.64]);
    color("#c0c0c0") for (i = [-1, 1], k = [-1, 1]) translate([i * joy_fori[0] / 2, k * joy_fori[1] / 2, -1.6 - 2]) cylinder(d = 5.5, h = 2);
}

module pulsante(c) {
    color("#1f1f1f") translate([-6, -6, 0]) cube([12, 12, pul_h]);
    color("#555") translate([-1.7, -1.7, pul_h]) cube([3.4, 3.4, 1]);
    color(c) translate([0, 0, pul_h + 0.6]) hull() {
        translate([-5, -5, 0]) cube([10, 10, 3]);
        translate([-4.3, -4.3, 0]) cube([8.6, 8.6, 5]);
    }
    color("#c0c0c0") for (s = [-1, 1], k = [-1, 1]) translate([s * 6.25 - 0.4, k * 2.5 - 0.4, -3.5]) cube([0.8, 0.8, 3.5]);
}

module pico() {
    color("#5b21b6") translate([-pm[0] / 2 + 0.3, pm_y0, pm_bot]) cube([pm[0] - 0.6, pm[1] - 0.6, pm_sp]);
    color("#c0c4c8") translate([-4.5, pm_y1 - 6.5, pm_top]) cube([9, 7.5, usb_h]);                     // presa USB-C
    color("#f2f2f2") translate([-2.2, pm_y1 - 13, pm_top]) cube([4.4, 3.4, 1.4]);                      // BOOTSEL
    color("#111") translate([-3.5, pm_y0 + 22, pm_top]) cube([7, 7, 0.9]);                             // RP2040
    color("#d4a017") for (s = [-1, 1], i = [0:19]) translate([s * 8.89, pm_y0 + 1.6 + i * 2.54, pm_top]) cylinder(d = 1.6, h = 0.05);
}

module componenti_sopra(leva = true, pulsanti_ok = true) {
    translate([joy[0], joy[1], z_pcb]) ky023(leva);
    if (pulsanti_ok) {
        for (i = [0:3]) translate([pul_pos(pulsanti[i])[0], pul_pos(pulsanti[i])[1], z_piast]) pulsante(col_tappi[i]);
        color(col_piast) translate([pul_c[0], pul_c[1], z_piast - piast_sp]) piastrina();
        color("#c0c0c0") translate([pul_c[0], pul_c[1], z_piast - piast_sp - 2]) cylinder(d = 5.5, h = 2);
    }
}

module viti_chiusura() color("#c0c0c0") for (v = viti) translate([v[0], v[1], 0]) {
    translate([0, 0, testa_z - 3]) cylinder(d = 5.5, h = 3);
    translate([0, 0, testa_z]) cylinder(d = 3, h = v[2]);
}

module capovolto() translate([0, 0, H]) rotate([180, 0, 0]) children();

module assieme(dz = 0) {
    color(col_sopra) translate([0, 0, dz]) sopra();
    color(col_sotto) sotto();
    translate([0, 0, dz]) componenti_sopra();
    pico();
}

module figura(f) {
    if (f == "f_pezzi") {
        translate([-150, 0, 0]) color(col_sopra) capovolto() sopra();
        translate([0, 0, z_min]) color(col_sotto) sotto();
        translate([115, 0, 0]) color(col_piast) piastrina();
    } else if (f == "f_joystick") {
        capovolto() { color(col_sopra) sopra(); componenti_sopra(true, false); }
    } else if (f == "f_pulsanti") {
        capovolto() { color(col_sopra) sopra(); componenti_sopra(true, true); }
    } else if (f == "f_pico") {
        color(col_sotto) sotto(); pico();
    } else if (f == "f_chiusura") {
        color(col_sotto) sotto(); pico(); translate([0, 0, -25]) viti_chiusura();
        translate([0, 0, 40]) { color(col_sopra) sopra(); componenti_sopra(true, true); }
    } else if (f == "f_finito") {
        color(col_sopra) sopra(); color(col_sotto) sotto(); componenti_sopra(true, true); pico();
    }
}

// ---------------------------------------------------------------- selezione (orientamento di stampa)
if (len(parte) > 2 && parte[0] == "f" && parte[1] == "_") figura(parte);
else if (parte == "assieme")   assieme();
else if (parte == "esploso")   assieme(35);
else if (parte == "sopra")     capovolto() sopra();
else if (parte == "sotto")     translate([0, 0, z_min]) sotto();
else if (parte == "piastrina") piastrina();
