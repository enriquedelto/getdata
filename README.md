# 🧙‍♂️ GetData Mod for Noita

[![Version](https://img.shields.io/badge/Version-1.4-blue?style=flat-square)](mod.xml) [![Platform](https://img.shields.io/badge/Platform-Windows-orange?style=flat-square)](#limitations) [![Status](https://img.shields.io/badge/Status-Working-brightgreen?style=flat-square)](#)

Un mod de utilidad simple para Noita que recopila información detallada sobre tus varitas y hechizos actuales y la **copia al portapapeles** con solo presionar una tecla. ¡Ideal para compartir builds, analizar estadísticas o simplemente curiosear!

---

## ✨ Características Clave

*   **⌨️ Activación Simple:** Presiona la tecla **`G`** para extraer y copiar los datos.
*   **📋 Copia al Portapapeles:** Toda la información se copia directamente, lista para pegar en cualquier editor de texto.
*   **📊 Datos Detallados de Varitas:** Incluye nombre, estadísticas (shuffle, capacidad, hechizos/cast, delays, mana, carga, spread) y la lista de hechizos que contiene.
*   **✨ Lista de Hechizos:** Muestra los hechizos dentro de cada varita (nombre, ID de acción).
*   **🎒 Hechizos de Inventario:** Lista los hechizos sueltos que llevas en el inventario.
*   **🔬 Estadísticas Base de Hechizos:** Recupera información base para cada hechizo único encontrado (costo de maná, usos, probabilidad de crítico, tipos de daño base, archivo de proyectil) leyendo los archivos XML y Lua del juego.

---

## 🚀 Cómo Usar

1.  Asegúrate de que el mod esté instalado y activado.
2.  Dentro del juego, presiona la tecla **`G`**.
3.  Verás brevemente un mensaje en la parte superior de la pantalla ("Info Copied!" o un error).
4.  ¡Pega (`Ctrl+V`) la información en tu editor de texto preferido!

---

## 📄 Ejemplo de Salida (Formato)

```text
=== Player Wands ===
Wand 1 (ID: 1234) Name: Speedy Wand
  Shuffle:           No
  Capacity:          8
  Spells/Cast:       1
  Cast Delay:        0.17
  Recharge Time:     0.50
  Mana:              150
  Mana Max:          150
  Mana Charge:       50
  Spread (deg):      0.00
    Spells:
      1: Spark Bolt (ID:SPARK_BOLT)
      2: Bouncing Burst (ID:BOUNCY_ORB)
... (más varitas) ...

=== Inventory Spells ===
1: Chainsaw (ID: CHAINSAW)
2: Energy Sphere (ID: ENERGY_SPHERE)
... (más hechizos) ...

=== Spell Base Details (Read from files) ===
Spark Bolt (ID: SPARK_BOLT):
  Mana Cost:        5
  Uses:             Infinite
  Critical Chance:  5%
  Base Damage:      Proj:3
  Projectile File:  data/entities/projectiles/spark_bolt.xml

Bouncing Burst (ID: BOUNCY_ORB):
  Mana Cost:        10
  Uses:             Infinite
  Critical Chance:  5%
  Base Damage:      Proj:2 Expl:5
  Projectile File:  data/entities/projectiles/deck/bouncy_orb.xml
... (más detalles de hechizos únicos) ...
```

---

## ⚙️ Requisitos y Dependencias

*   **Sistema Operativo:** **Windows** (Debido al uso de `FFI` para la funcionalidad del portapapeles).
*   **Archivo `nxml.lua`:** Este mod **incluye y requiere** el archivo `files/nxml.lua` (un parser XML en Lua) para leer los datos de los hechizos. Asegúrate de que esté presente en la carpeta `files`.
*   **Permisos de API:** El mod solicita `request_no_api_restrictions="1"` (ya configurado en `mod.xml`) para poder leer archivos del juego y usar FFI.

---

## 🛠️ Instalación

1.  Descarga el archivo ZIP del repositorio o clónalo.
2.  Extrae/coloca la carpeta completa `getdata` (que contiene `init.lua`, `mod.xml` y la subcarpeta `files`) dentro de tu directorio de mods de Noita (normalmente `Steam/steamapps/common/Noita/mods/`).
3.  Activa el mod "GetData" en el menú de mods de Noita antes de iniciar una nueva partida.

---

## ⚠️ Limitaciones y Posibles Problemas

*   **Solo Windows:** La función de copiar al portapapeles no funcionará en otros sistemas operativos.
*   **Pequeño Lag Inicial:** La *primera vez* que presiones 'G' en una sesión, puede haber un lag muy breve mientras el mod lee y cachea los datos de los archivos del juego (especialmente los XML). Las siguientes veces debería ser instantáneo.
*   **Precisión de Datos:** Las estadísticas base se obtienen parseando archivos del juego (`gun_actions.lua`, XMLs). Actualizaciones futuras de Noita *podrían* cambiar el formato de estos archivos y romper el parseo, requiriendo una actualización del mod.
*   **Conflictos:** Poco probable, pero mods que modifiquen drásticamente los componentes `AbilityComponent`, `ItemComponent` o la estructura de las varitas podrían causar lecturas incorrectas.

---

Disfruta analizando tus builds con facilidad. ¡Feedback y reportes de bugs son bienvenidos!
