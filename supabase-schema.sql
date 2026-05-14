-- ============================================
-- UNITEC Portal de Proveedores V4
-- Supabase Database Schema
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- TABLA: Proveedores
-- ============================================
CREATE TABLE proveedores (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  codigo VARCHAR(50) UNIQUE NOT NULL,
  nombre VARCHAR(255) NOT NULL,
  pais VARCHAR(100),
  contacto VARCHAR(255),
  email VARCHAR(255),
  telefono VARCHAR(50),
  notas TEXT,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- TABLA: Productos del Catálogo
-- ============================================
CREATE TABLE productos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ref_code VARCHAR(50) UNIQUE NOT NULL,
  nombre VARCHAR(255) NOT NULL,
  descripcion TEXT,
  categoria VARCHAR(100),
  m2_por_unidad DECIMAL(10,4),
  kg_por_m2 DECIMAL(10,4),
  precio_unitario DECIMAL(10,2),
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- TABLA: Órdenes de Compra
-- ============================================
CREATE TABLE ordenes_compra (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  consecutivo VARCHAR(50) UNIQUE NOT NULL,
  proveedor_id UUID REFERENCES proveedores(id) ON DELETE SET NULL,
  proveedor_nombre VARCHAR(255) NOT NULL, -- Desnormalizado para histórico
  pais_destino VARCHAR(100) NOT NULL,
  fecha DATE NOT NULL,
  total_peso_lbs DECIMAL(12,2),
  total_peso_kg DECIMAL(12,2),
  total_area_ft2 DECIMAL(12,2),
  total_area_m2 DECIMAL(12,2),
  total_monto DECIMAL(15,2),
  moneda VARCHAR(10) DEFAULT 'USD',
  notas TEXT,
  estado VARCHAR(50) DEFAULT 'borrador', -- borrador, enviada, confirmada, cancelada
  pdf_url TEXT,
  excel_url TEXT,
  created_by VARCHAR(255),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- TABLA: Detalle de Productos en Órdenes
-- ============================================
CREATE TABLE orden_productos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  orden_id UUID REFERENCES ordenes_compra(id) ON DELETE CASCADE,
  producto_id UUID REFERENCES productos(id) ON DELETE SET NULL,
  ref_code VARCHAR(50) NOT NULL,
  nombre_producto VARCHAR(255) NOT NULL,
  cantidad INTEGER NOT NULL,
  m2_por_unidad DECIMAL(10,4),
  kg_por_m2 DECIMAL(10,4),
  peso_total_lbs DECIMAL(12,2),
  peso_total_kg DECIMAL(12,2),
  area_total_ft2 DECIMAL(12,2),
  area_total_m2 DECIMAL(12,2),
  precio_unitario DECIMAL(10,2),
  subtotal DECIMAL(15,2),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- ÍNDICES para mejor performance
-- ============================================
CREATE INDEX idx_ordenes_consecutivo ON ordenes_compra(consecutivo);
CREATE INDEX idx_ordenes_proveedor ON ordenes_compra(proveedor_id);
CREATE INDEX idx_ordenes_fecha ON ordenes_compra(fecha DESC);
CREATE INDEX idx_ordenes_estado ON ordenes_compra(estado);
CREATE INDEX idx_productos_refcode ON productos(ref_code);
CREATE INDEX idx_orden_productos_orden ON orden_productos(orden_id);

-- ============================================
-- TRIGGER para actualizar updated_at
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_proveedores_updated_at
  BEFORE UPDATE ON proveedores
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_productos_updated_at
  BEFORE UPDATE ON productos
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ordenes_updated_at
  BEFORE UPDATE ON ordenes_compra
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================
ALTER TABLE proveedores ENABLE ROW LEVEL SECURITY;
ALTER TABLE productos ENABLE ROW LEVEL SECURITY;
ALTER TABLE ordenes_compra ENABLE ROW LEVEL SECURITY;
ALTER TABLE orden_productos ENABLE ROW LEVEL SECURITY;

-- Políticas públicas (ajustar según necesidades de autenticación)
CREATE POLICY "Enable read access for all users" ON proveedores FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON proveedores FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON proveedores FOR UPDATE USING (true);

CREATE POLICY "Enable read access for all users" ON productos FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON productos FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON productos FOR UPDATE USING (true);

CREATE POLICY "Enable read access for all users" ON ordenes_compra FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON ordenes_compra FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON ordenes_compra FOR UPDATE USING (true);

CREATE POLICY "Enable read access for all users" ON orden_productos FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON orden_productos FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON orden_productos FOR UPDATE USING (true);

-- ============================================
-- DATOS DE EJEMPLO (Opcional)
-- ============================================

-- Proveedores de ejemplo
INSERT INTO proveedores (codigo, nombre, pais, email) VALUES
('PROV001', 'Jasmel Acosta IA', 'China', 'jasmel@example.com'),
('PROV002', 'Building Materials Inc', 'China', 'contact@building.com'),
('PROV003', 'Global Construction Supply', 'Vietnam', 'info@globalcs.com');

-- Productos de ejemplo
INSERT INTO productos (ref_code, nombre, categoria, m2_por_unidad, kg_por_m2, precio_unitario) VALUES
('14122501', 'FACHADA EXTERIOR WOODMAX NATURAL', 'Wall Panels', 0.21, 4.5, 12.50),
('14031001', 'PISO SPC LANDY 38', 'Flooring', 1.89, 7.2, 28.00),
('14031002', 'PISO SPC PREMIUM 42', 'Flooring', 2.10, 7.8, 32.00),
('15012001', 'DECKING WPC CLASSIC', 'Decking', 0.146, 3.2, 18.50);

-- ============================================
-- VISTAS ÚTILES
-- ============================================

-- Vista de órdenes con totales
CREATE VIEW v_ordenes_resumen AS
SELECT 
  o.id,
  o.consecutivo,
  o.proveedor_nombre,
  o.pais_destino,
  o.fecha,
  o.estado,
  o.total_peso_kg,
  o.total_area_m2,
  o.total_monto,
  COUNT(op.id) as total_productos,
  o.created_at
FROM ordenes_compra o
LEFT JOIN orden_productos op ON o.id = op.orden_id
GROUP BY o.id;

-- Vista de productos más pedidos
CREATE VIEW v_productos_populares AS
SELECT 
  p.ref_code,
  p.nombre,
  COUNT(op.id) as veces_pedido,
  SUM(op.cantidad) as cantidad_total,
  SUM(op.subtotal) as monto_total
FROM productos p
LEFT JOIN orden_productos op ON p.id = op.producto_id
GROUP BY p.id, p.ref_code, p.nombre
ORDER BY veces_pedido DESC;

-- ============================================
-- FUNCIONES ÚTILES
-- ============================================

-- Función para generar consecutivo automático
CREATE OR REPLACE FUNCTION generar_consecutivo()
RETURNS TEXT AS $$
DECLARE
  ultimo_numero INTEGER;
  nuevo_consecutivo TEXT;
BEGIN
  SELECT COALESCE(MAX(CAST(SUBSTRING(consecutivo FROM 2) AS INTEGER)), 0)
  INTO ultimo_numero
  FROM ordenes_compra
  WHERE consecutivo ~ '^A#[0-9]+$';
  
  nuevo_consecutivo := 'A#' || LPAD((ultimo_numero + 1)::TEXT, 3, '0');
  RETURN nuevo_consecutivo;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- COMENTARIOS
-- ============================================
COMMENT ON TABLE proveedores IS 'Catálogo de proveedores internacionales';
COMMENT ON TABLE productos IS 'Catálogo de productos disponibles para órdenes';
COMMENT ON TABLE ordenes_compra IS 'Órdenes de compra generadas';
COMMENT ON TABLE orden_productos IS 'Detalle de productos por orden';
