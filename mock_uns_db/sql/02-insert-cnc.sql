USE labusine_db;
GO

INSERT INTO Room (Id, Nom, Largeur, Longueur, Hauteur)
VALUES ('room-001', 'Assembly Room', 15.0, 10.0, 5.0);

INSERT INTO EquipmentType (Nom, Description)
VALUES 
('CNC_Structure', ''),
('CNC_Bridge', ''),
('CNC_Rack', ''),
('CNC_Spindle', ''),
('CNC_Succion_zone1', 'Zone de succion 1'),
('CNC_Succion_zone2', 'Zone de succion 2'),
('CNC_Succion_zone3', 'Zone de succion 3'),
('CNC_Succion_zone4', 'Zone de succion 4'),
('CNC_Succion_zone5', 'Zone de succion 5'),
('CNC_Succion_zone6', 'Zone de succion 6');

INSERT INTO Manufacturer (Nom, Description)
VALUES 
('Test', 'Test'),
('LabUsine', 'Fait à linterne');

INSERT INTO Model (Nom, Description)
VALUES 
('Test', 'Test');

INSERT INTO Type (Nom, Description, Subtype)
VALUES
('PositionX', 'X position', 'float'),
('PositionY', 'Y position', 'float'),
('PositionZ', 'Z position', 'float'),
('RotationX', 'X rotation', 'float'),
('RotationY', 'Y rotation', 'float'),
('RotationZ', 'Z rotation', 'float'),
('Speed', 'Current speed', 'float'),
('Etat', 'Etat allumer (true) ou fermer (false)', 'bool'),
('DimensionX', 'Dimension sur axe X', 'float'),
('DimensionY', 'Dimension sur axe Y', 'float'),
('DimensionZ', 'Dimension sur axe Z', 'float');


-- Get lookup IDs
DECLARE @TypeCNC_Structure INT = (SELECT Id FROM EquipmentType WHERE Nom = 'CNC_Structure');
DECLARE @TypeCNC_Bridge INT = (SELECT Id FROM EquipmentType WHERE Nom = 'CNC_Bridge');
DECLARE @TypeCNC_Rack INT = (SELECT Id FROM EquipmentType WHERE Nom = 'CNC_Rack');
DECLARE @TypeCNC_Spindle INT = (SELECT Id FROM EquipmentType WHERE Nom = 'CNC_Spindle');
DECLARE @TypeCNC_Succion_zone1 INT = (SELECT Id FROM EquipmentType WHERE Nom = 'CNC_Succion_zone1');
DECLARE @TypeCNC_Succion_zone2 INT = (SELECT Id FROM EquipmentType WHERE Nom = 'CNC_Succion_zone2');
DECLARE @TypeCNC_Succion_zone3 INT = (SELECT Id FROM EquipmentType WHERE Nom = 'CNC_Succion_zone3');
DECLARE @TypeCNC_Succion_zone4 INT = (SELECT Id FROM EquipmentType WHERE Nom = 'CNC_Succion_zone4');
DECLARE @TypeCNC_Succion_zone5 INT = (SELECT Id FROM EquipmentType WHERE Nom = 'CNC_Succion_zone5');
DECLARE @TypeCNC_Succion_zone6 INT = (SELECT Id FROM EquipmentType WHERE Nom = 'CNC_Succion_zone6');

DECLARE @Mfr INT = (SELECT Id FROM Manufacturer WHERE Nom = 'Test');
DECLARE @Mfr_interne INT = (SELECT Id FROM Manufacturer WHERE Nom = 'LabUsine');
DECLARE @Model INT = (SELECT Id FROM Model WHERE Nom = 'Test');


-- Insert Equipment
INSERT INTO Equipment (Id, AssetUuid, ParentEquipmentId, EquipmentTypeId, ManufacturerId, ModelId, RoomId, Nom, PrefabKey, SerialNumber, PurchaseDate)
VALUES 
('CNC_Structure', 'CNC', NULL, @TypeCNC_Structure, @Mfr, @Model, 'room-001', 'CNC_Structure', 'CNC_Structure', '', '2025-07-11'),
('CNC_Bridge', 'CNC', 'CNC_Structure', @TypeCNC_Bridge, @Mfr, @Model, 'room-001', 'CNC_Bridge', NULL, '', '2025-07-11'),
('CNC_Rack', 'CNC', 'CNC_Bridge', @TypeCNC_Rack, @Mfr, @Model, 'room-001', 'CNC_Rack', NULL, '', '2025-07-11'),
('CNC_Spindle', 'CNC', 'CNC_Rack', @TypeCNC_Spindle, @Mfr, @Model, 'room-001', 'CNC_Spindle', NULL, '', '2025-07-11'),
('CNC_Succion_zone1', 'CNC', 'CNC_Structure', @TypeCNC_Succion_zone1, @Mfr_interne, @Model, 'room-001', 'CNC_Succion_zone1', 'CNC_Succion_zone1', null, null),
('CNC_Succion_zone2', 'CNC', 'CNC_Structure', @TypeCNC_Succion_zone2, @Mfr_interne, @Model, 'room-001', 'CNC_Succion_zone2', 'CNC_Succion_zone2', null, null),
('CNC_Succion_zone3', 'CNC', 'CNC_Structure', @TypeCNC_Succion_zone3, @Mfr_interne, @Model, 'room-001', 'CNC_Succion_zone3', 'CNC_Succion_zone3', null, null),
('CNC_Succion_zone4', 'CNC', 'CNC_Structure', @TypeCNC_Succion_zone4, @Mfr_interne, @Model, 'room-001', 'CNC_Succion_zone4', 'CNC_Succion_zone4', null, null),
('CNC_Succion_zone5', 'CNC', 'CNC_Structure', @TypeCNC_Succion_zone5, @Mfr_interne, @Model, 'room-001', 'CNC_Succion_zone5', 'CNC_Succion_zone5', null, null),
('CNC_Succion_zone6', 'CNC', 'CNC_Structure', @TypeCNC_Succion_zone6, @Mfr_interne, @Model, 'room-001', 'CNC_Succion_zone6', 'CNC_Succion_zone6', null, null);


-- Get Type IDs
DECLARE @TypePositionX INT = (SELECT Id FROM Type WHERE Nom = 'PositionX');
DECLARE @TypePositionY INT = (SELECT Id FROM Type WHERE Nom = 'PositionY');
DECLARE @TypePositionZ INT = (SELECT Id FROM Type WHERE Nom = 'PositionZ');
DECLARE @TypeRotationX INT = (SELECT Id FROM Type WHERE Nom = 'RotationX');
DECLARE @TypeRotationY INT = (SELECT Id FROM Type WHERE Nom = 'RotationY');
DECLARE @TypeRotationZ INT = (SELECT Id FROM Type WHERE Nom = 'RotationZ');

DECLARE @TypeSpeed INT = (SELECT Id FROM Type WHERE Nom = 'Speed');
DECLARE @TypeEtat INT = (SELECT Id FROM Type WHERE Nom = 'Etat');

DECLARE @TypeDimensionX INT = (SELECT Id FROM Type WHERE Nom = 'DimensionX');
DECLARE @TypeDimensionY INT = (SELECT Id FROM Type WHERE Nom = 'DimensionY');
DECLARE @TypeDimensionZ INT = (SELECT Id FROM Type WHERE Nom = 'DimensionZ');


-- Succion state for CNC_Succion_zone1
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone1', 'Etat', '1', @TypeEtat);
DECLARE @VarEtatZone1 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarEtatZone1, 'false');

-- Succion state for CNC_Succion_zone2
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone2', 'Etat', '2', @TypeEtat);
DECLARE @VarEtatZone2 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarEtatZone2, 'false');

-- Succion state for CNC_Succion_zone3
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone3', 'Etat', '3', @TypeEtat);
DECLARE @VarEtatZone3 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarEtatZone3, 'false');

-- Succion state for CNC_Succion_zone4
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone4', 'Etat', '4', @TypeEtat);
DECLARE @VarEtatZone4 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarEtatZone4, 'false');

-- Succion state for CNC_Succion_zone5
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone5', 'Etat', '5', @TypeEtat);
DECLARE @VarEtatZone5 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarEtatZone5, 'false');

-- Succion state for CNC_Succion_zone6
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone6', 'Etat', '6', @TypeEtat);
DECLARE @VarEtatZone6 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarEtatZone6, 'false');


-- Succion zone position CNC_Succion_zone1
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone1', 'PositionX', '7', @TypePositionX);
DECLARE @VarPositionXZone1 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarPositionXZone1, '0.0');

INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone1', 'PositionY', '8', @TypePositionY);
DECLARE @VarPositionYZone1 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarPositionYZone1, '0.0');


-- Succion zone position CNC_Succion_zone2
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone2', 'PositionX', '9', @TypePositionX);
DECLARE @VarPositionXZone2 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarPositionXZone2, '762.0');

INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone2', 'PositionY', '10', @TypePositionY);
DECLARE @VarPositionYZone2 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarPositionYZone2, '0.0');


-- Succion zone position CNC_Succion_zone3
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone3', 'PositionX', '11', @TypePositionX);
DECLARE @VarPositionXZone3 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarPositionXZone3, '1219.2');

INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone3', 'PositionY', '12', @TypePositionY);
DECLARE @VarPositionYZone3 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarPositionYZone3, '0.0');


-- Succion zone position CNC_Succion_zone4
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone4', 'PositionX', '13', @TypePositionX);
DECLARE @VarPositionXZone4 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarPositionXZone4, '0.0');

INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone4', 'PositionY', '14', @TypePositionY);
DECLARE @VarPositionYZone4 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarPositionYZone4, '1524.0');


-- Succion zone position CNC_Succion_zone5
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone5', 'PositionX', '15', @TypePositionX);
DECLARE @VarPositionXZone5 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarPositionXZone5, '1219.2');

INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone5', 'PositionY', '16', @TypePositionY);
DECLARE @VarPositionYZone5 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarPositionYZone5, '1524.0');


-- Succion zone position CNC_Succion_zone6
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone6', 'PositionX', '17', @TypePositionX);
DECLARE @VarPositionXZone6 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarPositionXZone6, '0.0');

INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone6', 'PositionY', '18', @TypePositionY);
DECLARE @VarPositionYZone6 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarPositionYZone6, '2438.4');


-- Succion dimension for CNC_Succion_zone1
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone1', 'DimensionX', '19', @TypeDimensionX);
DECLARE @VarDimensionXZone1 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarDimensionXZone1, '762');

INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone1', 'DimensionY', '20', @TypeDimensionY);
DECLARE @VarDimensionYZone1 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarDimensionYZone1, '1524');

-- Succion dimension for CNC_Succion_zone2
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone2', 'DimensionX', '21', @TypeDimensionX);
DECLARE @VarDimensionXZone2 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarDimensionXZone2, '457.2');

INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone2', 'DimensionY', '22', @TypeDimensionY);
DECLARE @VarDimensionYZone2 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarDimensionYZone2, '1524');

-- Succion dimension for CNC_Succion_zone3
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone3', 'DimensionX', '23', @TypeDimensionX);
DECLARE @VarDimensionXZone3 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarDimensionXZone3, '304.8');

INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone3', 'DimensionY', '24', @TypeDimensionY);
DECLARE @VarDimensionYZone3 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarDimensionYZone3, '1524');

-- Succion dimension for CNC_Succion_zone4
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone4', 'DimensionX', '25', @TypeDimensionX);
DECLARE @VarDimensionXZone4 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarDimensionXZone4, '1219.2');

INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone4', 'DimensionY', '26', @TypeDimensionY);
DECLARE @VarDimensionYZone4 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarDimensionYZone4, '914.4');

-- Succion dimension for CNC_Succion_zone5
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone5', 'DimensionX', '27', @TypeDimensionX);
DECLARE @VarDimensionXZone5 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarDimensionXZone5, '304.8');

INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone5', 'DimensionY', '28', @TypeDimensionY);
DECLARE @VarDimensionYZone5 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarDimensionYZone5, '914.4');

-- Succion dimension for CNC_Succion_zone6
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone6', 'DimensionX', '29', @TypeDimensionX);
DECLARE @VarDimensionXZone6 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarDimensionXZone6, '1524');

INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId) VALUES ('CNC_Succion_zone6', 'DimensionY', '30', @TypeDimensionY);
DECLARE @VarDimensionYZone6 INT = SCOPE_IDENTITY();
INSERT INTO Data (VariableId, Value) VALUES (@VarDimensionYZone6, '609.6');




-- Transform for CNC_Structure
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId)
VALUES ('CNC_Structure', 'PositionX', '25', @TypePositionX);
DECLARE @VarPositionXStructure INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value)
VALUES (@VarPositionXStructure, '3.65');
--
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId)
VALUES ('CNC_Structure', 'PositionY', '26', @TypePositionY);
DECLARE @VarPositionYStructure INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value)
VALUES (@VarPositionYStructure, '0.8');
--
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId)
VALUES ('CNC_Structure', 'PositionZ', '27', @TypePositionZ);
DECLARE @VarPositionZStructure INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value)
VALUES (@VarPositionZStructure, '5.12');
--
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId)
VALUES ('CNC_Structure', 'RotationY', '28', @TypeRotationY);
DECLARE @VarRotationYStructure INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value)
VALUES (@VarRotationYStructure, '270');

-- Transform for CNC_Bridge
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId)
VALUES ('CNC_Bridge', 'PositionZ', '29', @TypePositionZ);
DECLARE @VarPositionZBridge INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value)
VALUES (@VarPositionZBridge, '-1000.0');

-- Transform for CNC_Rack
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId)
VALUES ('CNC_Rack', 'PositionX', '30', @TypePositionX);
DECLARE @VarPositionXRack INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value)
VALUES (@VarPositionXRack, '-500.0');

-- Transform for CNC_Spindle
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId)
VALUES ('CNC_Spindle', 'PositionY', '31', @TypePositionY);
DECLARE @VarPositionYSpindle INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value)
VALUES (@VarPositionYSpindle, '-280.0');

-- Speed for CNC_Spindle
INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId)
VALUES ('CNC_Spindle', 'Speed', '32', @TypeSpeed);
DECLARE @VarSpeedSpindle INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value)
VALUES (@VarSpeedSpindle, '5.0');
