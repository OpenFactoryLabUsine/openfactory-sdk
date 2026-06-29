USE labusine_db;
GO

INSERT INTO EquipmentType (Nom, Description)
VALUES
('DustSensor', 'Dust sensor device for measuring particulate matter.');

INSERT INTO Manufacturer (Nom, Description)
VALUES
('TSI Incorporated', 'TSI Incorporated manufactures precision environmental measurement equipment.');

INSERT INTO Model (Nom, Description)
VALUES
('DustTrak_Model', 'DustTrak environmental monitor model.');

INSERT INTO Type (Nom, Description)
VALUES
('PM1Concentration', 'Particulate matter concentration for particles smaller than 1 micron.'),
('PM2_5Concentration', 'Particulate matter concentration for particles smaller than 2.5 microns.'),
('PM4Concentration', 'Particulate matter concentration for particles smaller than 4 microns.'),
('PM10Concentration', 'Particulate matter concentration for particles smaller than 10 microns.');

IF NOT EXISTS (SELECT 1 FROM Room WHERE Id = 'plt-3013')
BEGIN
    INSERT INTO Room (Id, Nom, Largeur, Longueur, Hauteur)
    VALUES ('plt-3013', 'DustTrak Room', 10.0, 10.0, 3.0);
END;

INSERT INTO Equipment (Id, AssetUuid, ParentEquipmentId, EquipmentTypeId, ManufacturerId, ModelId, RoomId, Nom, PrefabKey, SerialNumber, PurchaseDate)
SELECT 
    'DustTrak', 
    'DUSTTRAK', 
    NULL, 
    (SELECT Id FROM EquipmentType WHERE Nom = 'DustSensor'), 
    (SELECT Id FROM Manufacturer WHERE Nom = 'TSI Incorporated'), 
    (SELECT Id FROM Model WHERE Nom = 'DustTrak_Model'), 
    'plt-3013', 
    'DustTrak', 
    'DustTrak_Prefab', 
    'DustTrak_Serial_001', 
    '2025-07-11';

INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'DustTrak'), 'pm1_concentration', 'pm1_concentration', (SELECT Id FROM Type WHERE Nom = 'PM1Concentration'));

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (SCOPE_IDENTITY(), '0.0', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'DustTrak'), 'pm2_5_concentration', 'pm2_5_concentration', (SELECT Id FROM Type WHERE Nom = 'PM2_5Concentration'));

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (SCOPE_IDENTITY(), '0.0', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'DustTrak'), 'pm4_concentration', 'pm4_concentration', (SELECT Id FROM Type WHERE Nom = 'PM4Concentration'));

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (SCOPE_IDENTITY(), '0.0', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, OpenFactoryVariableId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'DustTrak'), 'pm10_concentration', 'pm10_concentration', (SELECT Id FROM Type WHERE Nom = 'PM10Concentration'));

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (SCOPE_IDENTITY(), '0.0', CURRENT_TIMESTAMP);