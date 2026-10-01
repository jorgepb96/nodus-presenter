# Protocolo nativo v1

Bonjour `_nodus-presenter._tcp`, servicio `nodus-<UUID>`, TCP con Network.framework y `includePeerToPeer = true` en listener, navegador y conexiones. El QR `nodus-presenter://pair?version=1&service=…&key=…&name=…` contiene una clave aleatoria de 256 bits que caduca al terminar la presentación. No incluye una dirección IP ni depende del router. Se intercambia por un pipe privado entre Electron y su helper: no va en argv, logs, endpoints HTTP ni repositorios.

TLS 1.2 PSK AES-128-GCM usa la clave del QR y el nombre del servicio como identidad. No hay certificados autofirmados ni excepciones de validación. Dos conexiones autenticadas, `control` y `assets`, evitan que las imágenes y PDF ocupen la cola de las órdenes. Cada frame lleva longitud uint32 big-endian y JSON UTF-8; máximo 1 MiB. `hello` declara versión, canal e ID aleatorio del dispositivo. El Mac limita las conexiones a 16 y cancela peers sin hello después de 10 segundos.

Control: `action {commandId,action}`, `volume {value}`, `ping`. La app no envía snapshots ni nombres de archivos. Electron valida y limita cada acción antes de ejecutar su reducer, descarta commandId duplicados (ventana de 4096 IDs) y responde `update {state,action?,origin?}`. En hello responde con estado, metadatos `deck {name,notes,videos,assetVersion}` y un replay acotado del overlay de la diapositiva. Todas las ventanas y el navegador reciben las mismas órdenes. El reloj lo mantiene Electron incluso con la consola del presentador cerrada.

Assets: `image {page,width,assetVersion}` responde JPEG de hasta 1280 px. `pdf {offset,assetVersion}` responde `pdfBegin {size,offset,assetVersion}`, chunks de 64 KiB (`pdfChunk {offset,data,assetVersion}`), `pdfEnd {sha256,assetVersion}`. El helper solo accede al PDF de la sesión que recibe por su pipe, nunca a rutas propuestas por el móvil. La app reanuda desde su archivo parcial, verifica SHA-256 y renombra al completarlo. Tamaño máximo 512 MiB, caché de imágenes 24 MiB, limpieza de documentos con más de siete días al iniciar. La descarga tiene un único vuelo por versión.

Heartbeat cada segundo, desconexión tras 12 segundos sin respuesta, reintentos 1/2/4/8 segundos. Cada intento tiene una generación: los callbacks antiguos no pueden volver verde una sesión nueva. El segundo plano suspende conexiones y cancela reintentos; al volver se descubre y autentica de nuevo. Las órdenes durante una caída se descartan, sin reproducción tardía.

El uso de peer-to-peer habilita una ruta posible, no fuerza que el sistema deje de utilizar una infraestructura disponible. Las pruebas de loopback verifican cifrado y bytes, no la ruta AWDL ni su coexistencia con el Wi-Fi del Mac.

## Transporte adicional para Windows/Linux

El QR v1, el descubrimiento Bonjour y los parámetros PSK del Mac se conservan. `Pairing.lan == nil` sigue la implementación original. Un QR v2 con `transport=lan` incluye `hosts` (hasta ocho IPv4), `port`, `service`, `key` y `fingerprint` (SHA-256 de los bytes DER del certificado de sesión). No se acepta un nombre DNS, puerto vacío/fuera de rango, fingerprint inválido ni campos duplicados. La clave y el certificado se renuevan al iniciar otra presentación.

La conexión usa TLS 1.3 con certificado P-256 efímero. El cliente verifica exactamente el fingerprint del QR mediante Network.framework antes de enviar `hello {version:1,channel,deviceId,key}`. Esta comprobación se aplica únicamente a la nueva vía; no hay excepciones globales ni cambios en `PresenterTLS.parameters` del Mac. Las conexiones de control compiten entre las direcciones del QR; gana la primera que entrega un snapshot válido tras autenticarse. Se cancelan las restantes y el canal de recursos usa el extremo ganador.

Los frames, comandos, PDF/SHA-256, vistas previas, watchdog, generaciones, reintentos y lectura privada se comparten con la vía actual. El punto verde solo aparece al recibir un estado autenticado. Una caída conserva el PDF/las notas y descarta las órdenes que no pueden entregarse. Ambos dispositivos deben estar en una red local accesible; esta vía no proporciona AWDL ni continuidad si desaparece la red. El navegador de Nodus conserva su acceso independiente con PIN.

Windows/Linux controla el volumen del vídeo en la ventana del público; Mac conserva el volumen del sistema. La etiqueta del cliente cambia entre «Video volume» y «Mac volume» y los controles multimedia siguen ocultos si no hay vídeo o se está leyendo en privado.
