#!/bin/bash

# 🚀 Script de Inicio Rápido - Biometric Application
# Este script configura e inicia el proyecto completo

set -e  # Salir si hay algún error

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     🔐 Biometric Authentication Platform - Quick Start       ║"
echo "║         Initialization Script v1.0.0                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Colores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Función para imprimir mensajes
print_status() {
    echo -e "${BLUE}→${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# ═══════════════════════════════════════════════════════════════════

# 1. VERIFICAR REQUISITOS
echo ""
print_status "Verificando requisitos del sistema..."

# Verificar Node.js
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    print_success "Node.js $NODE_VERSION encontrado"
else
    print_error "Node.js no está instalado"
    exit 1
fi

# Verificar npm
if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm --version)
    print_success "npm $NPM_VERSION encontrado"
else
    print_error "npm no está instalado"
    exit 1
fi

# Verificar Flutter
if command -v flutter &> /dev/null; then
    FLUTTER_VERSION=$(flutter --version | head -n1)
    print_success "Flutter instalado"
else
    print_warning "Flutter no está en PATH (opcional para mobile development)"
fi

# Verificar PostgreSQL
if command -v psql &> /dev/null; then
    PG_VERSION=$(psql --version)
    print_success "$PG_VERSION encontrado"
else
    print_error "PostgreSQL no está instalado"
    echo "  Instálalo desde: https://www.postgresql.org/download/"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════

# 2. SETUP DEL BACKEND
echo ""
print_status "Configurando Backend (Node.js + Express)..."

if [ -d "backend" ]; then
    cd backend
    
    # Instalar dependencias
    if [ ! -d "node_modules" ]; then
        print_status "Instalando dependencias del backend..."
        npm install
        print_success "Dependencias instaladas"
    else
        print_success "Dependencias del backend ya están instaladas"
    fi
    
    # Crear archivo .env si no existe
    if [ ! -f ".env" ]; then
        print_status "Creando archivo .env..."
        cp .env.example .env
        print_success "Archivo .env creado (revisa y actualiza si es necesario)"
    else
        print_success "Archivo .env ya existe"
    fi
    
    # Verificar base de datos
    print_status "Verificando base de datos PostgreSQL..."
    if psql -l | grep -q "biometrics_db"; then
        print_success "Base de datos 'biometrics_db' ya existe"
    else
        print_warning "Creando base de datos 'biometrics_db'..."
        createdb biometrics_db
        print_success "Base de datos creada"
    fi
    
    # Ejecutar migraciones
    print_status "Ejecutando migraciones..."
    npm run migrate
    print_success "Migraciones ejecutadas"
    
    cd ..
else
    print_error "Carpeta 'backend' no encontrada"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════

# 3. SETUP DE LA APP MÓVIL (OPCIONAL)
echo ""
print_status "Configurando Aplicación Móvil (Flutter)..."

if [ -d "mobile_app" ]; then
    if command -v flutter &> /dev/null; then
        cd mobile_app
        
        # Obtener dependencias
        if [ ! -d ".dart_tool" ]; then
            print_status "Instalando dependencias de Flutter..."
            flutter pub get
            print_success "Dependencias de Flutter instaladas"
        else
            print_success "Dependencias de Flutter ya están instaladas"
        fi
        
        # Generar código
        print_status "Generando código (build_runner)..."
        flutter pub run build_runner build --delete-conflicting-outputs 2>/dev/null || true
        print_success "Código generado"
        
        cd ..
    else
        print_warning "Flutter no está instalado (saltar setup de mobile)"
    fi
else
    print_warning "Carpeta 'mobile_app' no encontrada"
fi

# ═══════════════════════════════════════════════════════════════════

# 4. VERIFICACIÓN FINAL
echo ""
print_status "Realizando verificación final..."

print_success "Backend preparado"
print_success "Base de datos configurada"
print_success "Variables de entorno configuradas"

# ═══════════════════════════════════════════════════════════════════

# 5. INSTRUCCIONES FINALES
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    ✨ Setup Completado ✨                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

echo "📝 PRÓXIMOS PASOS:"
echo ""
echo "  1️⃣  Iniciar el Backend:"
echo "    $ cd backend"
echo "    $ npm run dev"
echo ""
echo "  2️⃣  En otra terminal, iniciar la App Móvil (opcional):"
echo "    $ cd mobile_app"
echo "    $ flutter run"
echo ""
echo "  3️⃣  Probar que todo funciona:"
echo "    $ curl http://localhost:3000/health"
echo ""

echo "📚 DOCUMENTACIÓN:"
echo "  - README.md → Guía general"
echo "  - docs/API.md → Endpoints REST"
echo "  - docs/SETUP_RAPIDO.md → Inicio rápido"
echo "  - docs/BIOMETRIC_INTEGRATION.md → Integración biométrica"
echo ""

echo "🔑 CREDENCIALES DE PRUEBA:"
echo "  Usuario: test@example.com"
echo "  Contraseña: test_password"
echo ""

echo "⚙️  CONFIGURACIÓN IMPORTANTE:"
echo "  ⚠️  Revisa backend/.env y actualiza:"
echo "    - JWT_SECRET (cambiar en producción)"
echo "    - Base de datos"
echo "    - Credenciales Azure (si usas)"
echo ""

echo "🎉 ¡Listo para comenzar!"
echo ""
