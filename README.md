# Bunker Verificarte (Flutter Web)

Plataforma de registro y certificacion de obras con certificados por edicion, transferencia de propiedad y panel de administracion. Este repositorio contiene solo el frontend Flutter Web listo para conectar al puente PHP `api_master.php`.

## Stack
- Flutter Web
- API Bridge: `api_master.php` (PHP 8.2 + MariaDB) ya existente en servidor

## Funcionalidades principales
- Registro e inicio de sesion
- Publicacion de obras (solo artista/administrador)
- Certificados por edicion con plantilla oficial
- Transferencia de certificados
- Panel de administracion
- Terminos y condiciones + aviso de privacidad con aceptacion obligatoria

## Requisitos
- Flutter 3.x
- Dart 3.x

## Ejecutar en local
```powershell
cd C:\Flutter\verificarte_web\verificarteweb
flutter pub get
flutter run -d chrome --web-port 3000
```

## Build para produccion
```powershell
cd C:\Flutter\verificarte_web\verificarteweb
flutter build web --release
```

## Despliegue
Sube el contenido de `build/web` al document root del dominio. El backend real es un puente PHP ya instalado en el servidor.

## Notas
- No incluye backend Node ni Dart.
- No se suben archivos `.env` ni backups.
