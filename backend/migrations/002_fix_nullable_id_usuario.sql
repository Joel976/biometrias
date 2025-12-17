-- =====================================================
-- MIGRACIÓN 002: Hacer id_usuario nullable en tablas offline
-- Permite registro sin usuario cuando es offline
-- =====================================================

-- Hacer id_usuario nullable en sincronizaciones
ALTER TABLE IF EXISTS sincronizaciones
DROP CONSTRAINT sincronizaciones_id_usuario_fkey,
ALTER COLUMN id_usuario DROP NOT NULL,
ADD CONSTRAINT sincronizaciones_id_usuario_fkey 
  FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE;

-- Hacer id_usuario nullable en cola_sincronizacion
ALTER TABLE IF EXISTS cola_sincronizacion
DROP CONSTRAINT cola_sincronizacion_id_usuario_fkey,
ALTER COLUMN id_usuario DROP NOT NULL,
ADD CONSTRAINT cola_sincronizacion_id_usuario_fkey 
  FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE;

-- Hacer id_usuario nullable en errores_sync
ALTER TABLE IF EXISTS errores_sync
DROP CONSTRAINT errores_sync_id_usuario_fkey,
ALTER COLUMN id_usuario DROP NOT NULL,
ADD CONSTRAINT errores_sync_id_usuario_fkey 
  FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE;
