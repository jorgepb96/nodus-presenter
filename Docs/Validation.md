# Validación de la primera implementación

Comprobaciones realizadas en este Mac el 1 de octubre de 2026:

- Swift 6.2.3, Xcode 26.2, SDK iOS 26.2. Compilación del proyecto nativo para simulador y archivo iPhone firmado con el equipo existente.
- Cuatro pruebas de protocolo: QR y clave, fragmentación TCP en todos los puntos de corte, frames concatenados/oversize y navegación limitada de la demo.
- XCUITest: avanzar, lectura privada sin mover la presentación, regresar a la diapositiva en pantalla, demo identificada, pantalla negra, selección de Spotlight y panel de herramientas.
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
