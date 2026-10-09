# Nodus Presenter

Aplicación nativa para iPhone y iPad que controla el PDF Presenter de Nodus. SwiftUI, PDFKit y Network.framework, sin dependencias externas. iOS 18 o posterior; Liquid Glass nativo en iOS 26 y materiales del sistema en versiones anteriores.

## Usar

En Nodus Research para Mac, Windows o Linux, inicia una presentación, abre el QR y selecciona **App iPhone–iPad**. Escanéalo desde esta app. El QR contiene una clave efímera para esa presentación: no lo compartas. El acceso **Navegador web** de Nodus continúa disponible con su PIN.

En Mac, el enlace admite Wi-Fi entre dispositivos Apple (`includePeerToPeer`) sin crear un hotspot ni cambiar la red del Mac. Ambos dispositivos deben mantener Wi-Fi encendido y autorizar el acceso a la red local. El sistema elige la ruta disponible; la interfaz no presenta una conexión como directa si no puede comprobarla. No necesita internet para PDF, notas o controles. Los vídeos externos siguen necesitando conexión a su proveedor.

En Windows y Linux, el ordenador y el móvil deben estar en la misma red local; el ordenador puede usar Ethernet. El QR configura automáticamente los extremos y verifica el certificado de sesión con TLS 1.3. No hay que escribir direcciones ni PIN en la app. El permiso de red local y el firewall deben permitir la conexión. La app y el navegador pueden usarse a la vez. Este enlace necesita la integración LAN de Nodus y la nueva versión del cliente móvil.

La demo funciona sin ordenador, sin cámara y sin red. Genera un PDF local de ocho diapositivas y notas. Desde la build 23 no incluye controles de vídeo ni volumen, tanto en la vista de presentación como en Ajustes. El punto verde indica un estado recibido de Nodus en una sesión autenticada; la demo y la reconexión muestran rojo, además de texto.

Desde la build 22, el enlace `nodus-presenter://demo` también abre esa demo desde el escáner, el enlace manual o una URL externa. El [QR de demostración](AppStore/Demo/nodus-presenter-demo-qr.png) es permanente y no contiene claves de sesión. Escanearlo requiere cámara; la demo no establece ninguna conexión ni controla un ordenador. Se puede regenerar y verificar con `swift Scripts/generate-demo-qr.swift`.

## Controles

Las notas tienen su propio panel de lectura. Ajusta el reparto entre diapositiva y notas con el separador o el slider de Ajustes; en este último, el tamaño se aplica al soltar para mantener estable la hoja. El slider y el separador se detienen cuando la diapositiva ocupa el ancho disponible; en la distribución por columnas, cuando ocupa toda la altura útil. El límite se adapta a su proporción, al tamaño de la ventana y a la vista de la siguiente diapositiva. La siguiente diapositiva se puede mostrar u ocultar. El tema, el reparto y esta opción se conservan al cerrar la app. Hay nueve acentos, nombrados solo por su color: Violeta, Índigo, Cian, Carmesí, Naranja, Verde azulado, Ámbar, Azul y Púrpura. Los identificadores anteriores se conservan para mantener tus preferencias.

En Ajustes → Tema, selecciona **Sistema**, **Claro** u **Oscuro**. La apariencia se guarda junto con el tema. El logo de la cabecera y la pantalla inicial es vectorial: tanto su superficie como el símbolo adoptan la apariencia y el acento seleccionado. En oscuro, los acentos se aclaran conservando su tono; texto y superficies usan los colores semánticos del sistema, y Liquid Glass adapta sus materiales automáticamente.

Las flechas están centradas justo debajo de la diapositiva. Toca la mitad izquierda para retroceder y la derecha para avanzar, o usa el deslizamiento y la cuadrícula de miniaturas. Una herramienta activa recibe esos toques sin cambiar de diapositiva; su color, tamaño y borrado aparecen entre las flechas. Amplía o reduce la diapositiva con los botones o el gesto de pinza; arrastra una diapositiva ampliada para desplazarte por ella. El ojo permite leer la siguiente diapositiva en privado: tiene un área de 44 × 44 puntos y toda la fila de vista previa admite el toque. El botón para volver a la pantalla del público también tiene 44 puntos de alto. El cronómetro está en la cabecera: un toque pausa o inicia, y mantenerlo pulsado lo reinicia.

Una única barra inferior reúne puntero, Spotlight, dibujo, lupa y pantalla negra. La lectura privada permanece activa al pulsar una herramienta o la luna/sol. Sus acciones se aplican a la pantalla del público sin cambiar de diapositiva ni cancelar la lectura del móvil; solo pulsar de nuevo el libro vuelve a la diapositiva proyectada. Otro toque en una herramienta seleccionada la desactiva. También hay botones de fuente de 44 puntos separados, volumen y reproducción/búsqueda del vídeo asociado. Las herramientas actúan sobre las coordenadas de la diapositiva, sin las bandas del encuadre. Durante una desconexión se conserva la última vista y el contenido descargado; no se guardan órdenes para reproducirlas más tarde.

Si la diapositiva proyectada tiene vídeo, la franja bajo ella muestra reproducción/pausa a la izquierda y volumen a la derecha, con las flechas centradas. El volumen abre un popover con slider: controla el audio del sistema en Mac y el volumen del vídeo de la presentación en Windows/Linux, y comparte su valor con Ajustes. Las herramientas conservan sus controles entre las flechas. En columnas de menos de 340 puntos, los botones multimedia pasan junto al contador para evitar solapamientos. Se ocultan durante la lectura privada y no aparecen en la demo. Ajustes mantiene el salto a un segundo concreto para las sesiones reales.

## Idiomas

La interfaz, la demo, los errores, los permisos y las etiquetas de accesibilidad están disponibles en inglés, español, francés, chino simplificado y tradicional, japonés, alemán, italiano y portugués. La app usa automáticamente el idioma principal del dispositivo. Las variantes regionales comparten traducción; el chino distingue escritura simplificada/tradicional y las regiones de Taiwán, Hong Kong y Macao. Un idioma principal no disponible usa inglés. No modifica los PDF ni las notas enviados desde Nodus.

El catálogo está en `Localization/translations.json`. Ejecuta `python3 Scripts/generate-localizations.py` después de editarlo para regenerar los recursos nativos `.strings` y los mensajes de permisos. El generador y los tests comprueban cobertura y argumentos de formato. XCUITest arranca cada idioma mediante `-AppleLanguages`, sin cambiar el idioma del dispositivo, y comprueba también el fallback desde ruso.

## Construir y comprobar

```sh
brew install xcodegen
Scripts/configure-project.sh
swift test
xcodebuild -project NodusPresenter.xcodeproj -scheme NodusPresenter \
  -destination 'platform=iOS Simulator,name=Nodus — iPhone 16 Pro Max' CODE_SIGNING_ALLOWED=NO test
```

Abre `NodusPresenter.xcodeproj`. El equipo de firma se puede cambiar en `project.yml`. Argumentos de ejecución: `--demo`, `--demo --video` (abre la diapositiva 4), `--demo --tools`, `--demo --slides`. `--reset-preferences` restaura los ajustes visuales para las pruebas. `--pair <url>` se reserva para pruebas locales del protocolo; no uses claves reales en argumentos. En Debug del simulador, `--simulator-pair-file <ruta>` lee un QR de pruebas desde un archivo privado sin exponer su clave en argumentos o logs.

Para revisar el diseño en el Mac, compila con destino **Mac Catalyst** y ejecuta la app con `--demo`. Esta vista permite probar el mismo código SwiftUI; la validación final de gestos y conexión debe hacerse en iPhone/iPad.

Después de las pruebas de interfaz, usa `Scripts/relaunch-simulator.sh <UUID> <ruta/NodusPresenter.app> --demo` para revisar la app instalada. Comprueba que el bundle incluye su AppIcon y retira únicamente el ejecutor `NodusPresenterUITests-Runner` que Xcode deja con un icono vacío; conserva la app y sus preferencias.

`Scripts/configure-project.sh` detecta el SDK: con iOS 27.1 o posterior activa `NODUS_FOLDABLE_SDK`, que usa `ArrangementView` y `onHingeChange` para separar superficie y notas al plegar. Con SDK 26.2 compila el diseño por anchura y conserva la misma sesión al redimensionar. La rama específica de bisagra todavía necesita validación con SDK 27.1 y hardware plegable; las capturas anchas no son prueba de bisagra.

## Arquitectura y beta

[Protocolo](Docs/Protocol.md) · [Pruebas y límites](Docs/Validation.md) · [TestFlight](Docs/TestFlight.md) · [Privacidad](PRIVACY.md)

[Conceptos generados](Design/) y [capturas reales del simulador](Screenshots/) están separados. `App/NodusBrand.swift` comparte entre el logo interior y el icono del sistema la geometría de `nodus/shared/nodusMark.json` y los cuatro tonos opacos/degradado de `nodus/src/dockIcon.ts`. La N mantiene sus proporciones dentro de una pantalla con colores adaptativos. `sh Scripts/regenerate-icons.sh` genera los iconos claro y oscuro y la previsualización desde ese mismo dibujo; `Scripts/configure-project.sh` lo ejecuta automáticamente.

![Panel ajustable con controles de dibujo en iPhone 16 Pro Max](Screenshots/iphone16promax-drawing-build3.png)

Licencia AGPL-3.0; se conserva el archivo LICENSE del repositorio original.
