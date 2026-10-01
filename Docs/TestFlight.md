# Primera beta interna

Bundle ID `com.nodusresearch.presenter`, versión `0.1.0`, build `1`, equipo `6RPLS9EA4X`. La primera beta es interna para el titular; no se crean grupos externos ni enlaces públicos. El registro de App Store Connect se crea antes de subir el archivo.

```sh
Scripts/configure-project.sh
xcodebuild -project NodusPresenter.xcodeproj -scheme NodusPresenter \
  -destination 'generic/platform=iOS' -archivePath .build/NodusPresenter.xcarchive \
  -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath .build/NodusPresenter.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath .build/export -allowProvisioningUpdates
```

La sesión de Xcode debe pertenecer al equipo de firma. No se versionan claves p8, certificados p12 ni perfiles. `ExportOptions.plist` configura únicamente TestFlight interno. Una subida correcta todavía requiere esperar al procesamiento de Apple y asignar el build al grupo interno.

Texto de pruebas: prueba la demo local, navegación/lectura privada, notas y herramientas. Para una sesión real instala la integración nativa en Nodus para macOS, inicia Presenter y escanea el QR de App iPhone–iPad. Prueba la reconexión y verifica que el punto verde aparece solamente con una sesión activa.

No se requiere cuenta en la app ni se modifica la disponibilidad del App Store. La publicación del código en el repo privado no publica automáticamente la app en la tienda.
