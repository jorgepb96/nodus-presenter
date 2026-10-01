# Validación de la primera implementación

Comprobaciones realizadas en este Mac el 1 de octubre de 2026:

- Swift 6.2.3, Xcode 26.2, SDK iOS 26.2. Compilación del proyecto nativo para simulador y archivo iPhone firmado con el equipo existente.
- Compilación Mac Catalyst y arranque real de la demo en macOS para revisión visual.
- Cuatro pruebas de protocolo: QR y clave, fragmentación TCP en todos los puntos de corte, frames concatenados/oversize y navegación limitada de la demo.
- XCUITest en iPhone 16 Pro Max (runtime 26.3): navegación, toques por mitades y selección repetida desde la cuadrícula; lectura privada; zoom con botones y desplazamiento sin avanzar; botones de fuente de 44 puntos con separación; pantalla negra; Spotlight; controles de dibujo entre las flechas y borrado; dos ajustes de lupa contenidos en la fila central; cronómetro con toque y pulsación larga; siguiente diapositiva opcional; slider de reparto; tema Estudio y persistencia tras relanzar.
- Icono regenerado y comprobado visualmente. Las miniaturas pasivas no interceptan el toque de las celdas y usan una caché de menor resolución que la diapositiva principal.
- Apariencia adaptativa: prueba de interfaz en iPhone 16 Pro Max con iOS 26.3, seleccionando Docencia + Claro y Estudio + Oscuro, comprobando el tema/apariencia efectivos del logo, notas visibles, diapositiva conservada y persistencia tras relanzar. Capturas reales de [claro](../Screenshots/iphone16promax-light-docencia.png) y [oscuro](../Screenshots/iphone16promax-dark-estudio.png). Compilación Mac Catalyst también verificada.
- Capturas de la build 3 exportadas directamente de la ejecución de XCUITest: [panel](../Screenshots/iphone16promax-adjustable-build3.png), [dibujo](../Screenshots/iphone16promax-drawing-build3.png), [lupa](../Screenshots/iphone16promax-magnifier-build3.png) y [ajustes](../Screenshots/iphone16promax-settings-build3.png). Revisión ancha en [Mac Catalyst](../Screenshots/mac-adjustable-build3.png). La build 3 permanece local.
- Capturas reales de la demo en iPhone 17 Pro y iPad Pro (runtime 26.3), y arranque de la app en iPhone 16 Pro con iOS 18.2. Los conceptos gráficos de Design no se consideran capturas de la app.
- En Nodus: TypeScript de renderer y Electron, validación de acciones nativas/deduplicación, TLS real en loopback, clave errónea rechazada, vista JPEG y PDF completo con SHA-256, además de los tests existentes de reducer, PIN y rutas. Helper compilado para arm64 y x86_64.

Pendiente de comprobación física: QR con cámara, descubrimiento peer-to-peer entre Mac/iPhone, apagar el router conservando Wi-Fi, recuperar la sesión al perder una ruta, simultaneidad con el navegador y rendimiento con un PDF grande. Los dispositivos físicos registrados estaban desconectados durante esta implementación. El test TLS local no sustituye esas comprobaciones.

La adaptación por anchura está compilada y conserva la sesión en el modelo compartido. La rama con `ArrangementView`/`onHingeChange` se activa con SDK 27.1: el equipo tiene Xcode 26.2, por lo que esa rama no está compilada ni validada aquí. No se afirma compatibilidad física probada con el plegable.

Fuentes oficiales consultadas:

- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
- [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
- [ArrangementView](https://developer.apple.com/documentation/swiftui/arrangementview)
- [onHingeChange](https://developer.apple.com/documentation/swiftui/view/onhingechange(isenabled:_:))
- [includePeerToPeer](https://developer.apple.com/documentation/network/nwparameters/includepeertopeer)
- [TN3151: Choosing the right networking API](https://developer.apple.com/documentation/technotes/tn3151-choosing-the-right-networking-api)
