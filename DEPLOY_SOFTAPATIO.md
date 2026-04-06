# Despliegue de verificARTE en `verificarte.softapatio.mx`

Este proyecto ya tiene frontend listo para subir por FileZilla y respaldo SQL generado.

## 1. Lo mas importante antes de subir

Tu hosting compartido te sirve perfecto para:

- subir el frontend de Flutter Web
- importar la base de datos MySQL

Pero **Node.js** y el backend **Dart** normalmente necesitan un servidor que los ejecute de forma permanente.

Con los datos que compartiste, lo seguro es asumir esto:

- `verificarte.softapatio.mx` = frontend estatico
- MySQL del hosting = base de datos
- API Node + API Dart OTP = deben vivir en un servidor aparte **o** en un hosting que soporte procesos Node/Dart

## 2. Archivos listos que ya te deje

- Respaldo completo de base:
  - `backups/verificarte_2026-03-24.sql`
- Solo estructura:
  - `backups/verificarte_schema_2026-03-24.sql`
- Config Node produccion:
  - `node_api/.env.production`
- Config SMTP para backend Dart:
  - `.env.production`
- Reglas Apache para Flutter Web:
  - `web/.htaccess`

## 3. Base de datos: que archivo importar

Si quieres que el servidor quede igual que tus pruebas locales:

- importa `backups/verificarte_2026-03-24.sql`

Si quieres arrancar en limpio:

- importa `backups/verificarte_schema_2026-03-24.sql`

## 4. Como importar la base en el hosting

Hazlo desde phpMyAdmin o el panel MySQL del hosting.

Datos de base que me pasaste:

- Host: `db5020077295.hosting-data.io`
- Base: `dbs15474121`
- Usuario: `dbu3449997`

### Opcion A: phpMyAdmin

1. Abre phpMyAdmin desde el panel del hosting.
2. Entra a la base `dbs15474121`.
3. Usa la pestaña `Importar`.
4. Sube `backups/verificarte_2026-03-24.sql`.
5. Espera a que termine y revisa que aparezcan las tablas.

## 5. Frontend: como generar build para subir

Por ahora no te pongo URLs de produccion fijas en el build porque primero debemos saber donde van a vivir la API Node y la API OTP.

Mientras eso se define, puedes generar el frontend asi:

```powershell
cd C:\Flutter\verificarte_web\verificarteweb
flutter clean
flutter pub get
flutter build web --release
```

Eso genera:

- `build/web`

## 6. Que subir por FileZilla

Sube **el contenido de** `build/web`, no la carpeta entera.

O sea, al directorio publico del dominio subes:

- `index.html`
- `main.dart.js`
- `flutter.js`
- `flutter_bootstrap.js`
- `flutter_service_worker.js`
- `manifest.json`
- `version.json`
- carpeta `assets`
- carpeta `icons`
- carpeta `canvaskit`
- archivo `.htaccess`

## 7. Muy importante: API y OTP

El frontend no podra funcionar al 100% solo con FileZilla si no existe una API publica funcionando.

Necesitas dos URLs reales:

- API principal Node
- API OTP / correos

Cuando ya tengas esas dos URLs, el build final se hace asi:

```powershell
flutter build web --release ^
  --dart-define=API_URL=https://TU_API_NODE ^
  --dart-define=OTP_URL=https://TU_API_OTP
```

Ejemplo:

```powershell
flutter build web --release ^
  --dart-define=API_URL=https://api.verificarte.softapatio.mx ^
  --dart-define=OTP_URL=https://otp.verificarte.softapatio.mx
```

## 8. Si el hosting no soporta Node/Dart

Entonces tienes estas opciones:

1. dejar `verificarte.softapatio.mx` solo para el frontend
2. montar Node y Dart en:
   - un VPS
   - Railway
   - Render
   - una instancia Linux
3. conectar el frontend a esas URLs publicas

## 9. Como usar los .env de produccion

### Node API

En el servidor donde corra Node:

1. copia `node_api/.env.production`
2. renombralo a `.env`
3. inicia la API Node desde la carpeta `node_api`

### Backend Dart OTP

En el servidor donde corra Dart:

1. copia `.env.production`
2. renombralo a `.env` en la raiz del proyecto
3. ejecuta el backend Dart

## 10. Lo que aun falta definir

Para dejarte el despliegue cerrado al 100%, todavia necesitamos confirmar una de estas dos cosas:

- si tu hosting soporta Node.js y un proceso Dart vivo
- o si vas a usar otro servidor para las APIs

Sin eso, lo que si queda listo hoy es:

- frontend compilado
- base exportada
- reglas de rutas web
- variables de produccion preparadas

## 11. Recomendacion de seguridad

Como ya compartiste credenciales reales:

- cambia las contraseñas del hosting y base despues del primer despliegue
- rota tambien cualquier clave sensible cuando terminemos de montar
