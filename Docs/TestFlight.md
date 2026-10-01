# Beta interna 0.2.0

La versión actual es **0.2.0 (8)**, con el nombre **Nodus Presenter**. Se archivó, firmó y subió correctamente el 1 de octubre de 2026, y App Store Connect la muestra **En pruebas** en el grupo existente **Jorge — beta interna**. La build 8 comparte el dibujo original de la N entre el icono del sistema y los logos de cabecera/bienvenida, con sus cuatro tonos opacos, degradado diagonal, proporciones originales y variantes de AppIcon claro/oscuro. Conserva todas las correcciones de la build 7, que aplica inmediatamente al puntero y su halo el color seleccionado en el móvil, mantiene la lectura privada al usar herramientas o luna/sol y refleja la pantalla negra también en la vista del presentador. El libro resaltado permanece activo hasta que el usuario lo vuelve a pulsar; la navegación privada no cambia la diapositiva del público. Conserva los controles de audio/vídeo ocultos sin vídeo y durante la lectura privada, también en Ajustes. Las builds 4, 5, 6 y 7 anteriores siguen disponibles. No se han creado grupos externos ni enlaces públicos.

Las capturas y descripciones de la versión están en [AppStore](../AppStore/README.md). Las catorce capturas son nativas y en inglés. El registro del App Store permanece en preparación con la build 8 asociada; una beta en TestFlight no equivale a publicar la app públicamente.

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
