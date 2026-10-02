# Beta interna 0.2.0

**Correcciones pendientes de prueba física:** la rama del PR 2 prepara búsqueda Bonjour según el ejemplo oficial de Apple, cancelación antes de conectar, corrección de intentos duplicados por activación y errores de permisos/timeout diferenciados y traducidos. El Mac no cambia. El titular no puede usar el iPhone por ahora; se espera su prueba y no se ha subido una nueva build. El fallo inalámbrico todavía no se declara resuelto. Véase [la investigación y sus límites](ConnectionInvestigation.md).

La build **0.2.0 (11)** se firmó, archivó y subió correctamente el 2 de octubre de 2026 a las 10:28 (Europe/Madrid). Apple terminó de procesarla y se asignó al grupo existente **Jorge — beta interna**, con instrucciones de prueba guardadas en español. Mejora el arranque de la conexión Mac/iOS: resolución directa del servicio del QR, plazos separados para TLS y autenticación, control antes que recursos y recuperación independiente de la descarga. Mantiene el helper/TLS-PSK del Mac y la conexión Windows/Linux. Sus pruebas automatizadas son de simulador y sockets locales. **El titular probó esta build en un iPhone físico: sigue sin conectar en la Wi-Fi universitaria ni con Wi-Fi encendido y sin ninguna red de infraestructura; conecta rápido mediante el punto de acceso del iPhone. Este caso permanece sin resolver.** El Mac anuncia localmente la sesión también en su interfaz peer-to-peer. La investigación con el dispositivo real demuestra que USB transportaba la conexión y que el intento Wi-Fi se quedaba en preparación antes de TLS; véase [ConnectionInvestigation.md](ConnectionInvestigation.md). El fallo inalámbrico sigue sin una causa confirmada. La build 10 sigue siendo el binario del envío público, para el que Apple ha solicitado información y grabación física según Guideline 2.1.

La build **0.2.0 (10)** se firmó, archivó y subió correctamente el 2 de octubre de 2026. Añade el enlace a la [política de privacidad de Presenter](https://nodusresearch.com/presenter/privacy/) en bienvenida y Ajustes → Información, con etiquetas traducidas a los nueve idiomas. Conserva la implementación de conexión y controles de la build 9. Se verificó en un iPhone 16 Pro Max con iOS 26.3 y pasaron las 12 pruebas del núcleo. App Store Connect la muestra **En pruebas** en el grupo existente **Jorge — beta interna**, y la versión **0.2.0 (10)** se envió a revisión pública el 2 de octubre de 2026 a las 00:39 (Europe/Madrid). Inicialmente quedó **Pendiente de revisión**; Apple posteriormente solicitó información según Guideline 2.1. La publicación permanece gratuita y automática después de la aprobación de Apple. No se han creado grupos externos ni enlaces públicos de TestFlight.

La beta interna anterior es **0.2.0 (9)**, con el nombre **Nodus Presenter**. Se archivó, firmó y subió correctamente el 1 de octubre de 2026, y App Store Connect la muestra **En pruebas** en el grupo existente **Jorge — beta interna**, con las instrucciones de prueba guardadas. [Comprobante](../Screenshots/Connectivity/testflight-build9.png).

La build 9 añade emparejamiento nativo con Windows y Linux mediante QR y TLS 1.3. Requiere una versión de Nodus que incluya el [PR 1030](https://github.com/Drakonis96/nodus/pull/1030), ya fusionado en el repositorio principal. El ordenador y el móvil deben estar en una red local accesible; no necesita internet para PDF, notas o controles. El transporte directo del Mac conserva su implementación anterior. En Windows/Linux el volumen controla el vídeo del público, con la etiqueta «Volumen del vídeo»; en Mac continúa controlando la salida del sistema.

Conserva el logo original de la build 8 entre el icono del sistema y la interfaz, sus variantes claro/oscuro, los temas y todas las correcciones de la build 7: color inmediato del puntero, lectura privada persistente, pantalla negra y controles de vídeo/volumen ocultos sin vídeo y durante lectura privada. Las builds anteriores siguen disponibles. No se han creado grupos externos ni enlaces públicos.

Las capturas y descripciones de la versión están en [AppStore](../AppStore/README.md). Las catorce capturas son nativas y en inglés. La build 10 está asociada al envío de App Store, pendiente de revisión; una beta en TestFlight no equivale a publicar la app públicamente.

Bundle ID `com.nodusresearch.presenter`, equipo `6RPLS9EA4X`. `ExportOptions.plist` ya no limita el archivo a TestFlight interno, por lo que el mismo binario puede servir para una revisión futura de App Store. Su distribución actual sigue restringida al grupo interno existente.

## Historial de la primera beta

La build **3** incorpora el panel ajustable, los temas, el logo vectorial adaptado al acento y la apariencia, los modos Sistema/Claro/Oscuro y los nuevos controles. Está compilada para revisión local en el simulador iPhone 16 Pro Max (iOS 26.3) y en Mac Catalyst. **Todavía no se ha subido a TestFlight**; la beta interna disponible sigue siendo la build 2.

Bundle ID `com.nodusresearch.presenter`, versión `0.1.0`, build `2`, equipo `6RPLS9EA4X`. La primera beta es interna para el titular; no se crean grupos externos ni enlaces públicos. Registro [App Store Connect](https://appstoreconnect.apple.com/apps/6818107823/distribution). Los builds 1 y 2 se subieron correctamente a TestFlight interno. El build 2 separa el watchdog del canal de control del tráfico del PDF para que una descarga no pueda ocultar una pérdida de control.

```sh
Scripts/configure-project.sh
xcodebuild -project NodusPresenter.xcodeproj -scheme NodusPresenter \
  -destination 'generic/platform=iOS' -archivePath .build/NodusPresenter.xcarchive \
  -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath .build/NodusPresenter.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath .build/export -allowProvisioningUpdates
```

La sesión de Xcode debe pertenecer al equipo de firma. No se versionan claves p8, certificados p12 ni perfiles. La exportación inicial configuraba únicamente TestFlight interno. El 1 de octubre de 2026 se comprobó el build `0.1.0 (2)` en estado **Testing**, asignado al grupo **Jorge — beta interna**, con un único tester interno en estado **Invited**. El build 1 queda sin asignar. [Comprobante inicial](../Screenshots/testflight-internal.jpg). En futuras subidas hay que esperar al procesamiento de Apple y asignar el nuevo build al grupo interno.

Texto de pruebas: prueba la demo local, navegación/lectura privada, notas y herramientas. Para una sesión real instala la integración nativa en Nodus para macOS, inicia Presenter y escanea el QR de App iPhone–iPad. Prueba la reconexión y verifica que el punto verde aparece solamente con una sesión activa.

No se requiere cuenta en la app ni se modifica la disponibilidad del App Store. La publicación del código en el repo privado no publica automáticamente la app en la tienda.
