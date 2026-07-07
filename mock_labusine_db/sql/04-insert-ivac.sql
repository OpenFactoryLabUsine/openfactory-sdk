USE labusine_db;
GO

INSERT INTO EquipmentType (Nom, Description)
VALUES 
('BlastGate', 'Component used in dust collection systems to control airflow by directing it to different locations.'),
('Spindle', 'Rotating axis of a CNC machine.'),
('Lathe', 'Machine tool for shaping materials.');

INSERT INTO Manufacturer (Nom, Description)
VALUES 
('iVAC Industries', 'iVAC Industries manufactures automated wireless dust collection systems designed to instantly activate shop vacuums or large dust collectors whenever you turn on your power tools.');

INSERT INTO Model (Nom, Description)
VALUES 
('iVAC_Model', 'iVAC_Model');

INSERT INTO Type (Nom, Description, SubType)
VALUES 
('EquipmentMode', 'An indication that a piece of equipment, or a subpart of a piece of equipment, is performing specific types of activities.', 'Powered');

INSERT INTO Type (Nom, Description)
VALUES 
('DoorState', 'The operational state of a DOOR type component or composition element.');

INSERT INTO Type (Nom, Description)
VALUES
('Position', 'A numeric position coordinate for a component (X, Y, Z).'),
('Angle', 'A numeric angle coordinate for a component (X, Y, Z).');

IF NOT EXISTS (SELECT 1 FROM Room WHERE Id = 'plt-3013')
BEGIN
    INSERT INTO Room (Id, Nom, Largeur, Longueur, Hauteur)
    VALUES ('plt-3013', 'MainLab', 10.0, 10.0, 3.0);
END;

DECLARE @TypeSpindle INT = (SELECT Id FROM EquipmentType WHERE Nom = 'Spindle');
DECLARE @TypeLathe INT = (SELECT Id FROM EquipmentType WHERE Nom = 'Lathe');
DECLARE @TypeGate INT = (SELECT Id FROM EquipmentType WHERE Nom = 'BlastGate');
DECLARE @Mfr INT = (SELECT Id FROM Manufacturer WHERE Nom = 'iVAC Industries');
DECLARE @Model INT = (SELECT Id FROM Model WHERE Nom = 'iVAC_Model');

INSERT INTO Equipment (Id, AssetUuid, ParentEquipmentId, EquipmentTypeId, ManufacturerId, ModelId, RoomId, Nom, PrefabKey, SerialNumber, PurchaseDate)
VALUES 
('A1ToolPlus', 'IVAC', NULL, @TypeSpindle, @Mfr, @Model, 'plt-3013', 'A1ToolPlus', 'A1ToolPlus_Prefab', 'iVAC_Serial_001', '2025-07-11'),
('A2ToolPlus', 'IVAC', NULL, @TypeSpindle, @Mfr, @Model, 'plt-3013', 'A2ToolPlus', 'A2ToolPlus_Prefab', 'iVAC_Serial_002', '2025-07-11'),
('A3ToolPlus', 'IVAC', NULL, @TypeSpindle, @Mfr, @Model, 'plt-3013', 'A3ToolPlus', 'A3ToolPlus_Prefab', 'iVAC_Serial_003', '2025-07-11'),
('A1BlastGate', 'IVAC', NULL, @TypeGate, @Mfr, @Model, 'plt-3013', 'A1BlastGate', 'A1BlastGate_Prefab', 'iVAC_Serial_004', '2025-07-11'),
('A2BlastGate', 'IVAC', NULL, @TypeGate, @Mfr, @Model, 'plt-3013', 'A2BlastGate', 'A2BlastGate_Prefab', 'iVAC_Serial_005', '2025-07-11'),
('A3BlastGate', 'IVAC', NULL, @TypeGate, @Mfr, @Model, 'plt-3013', 'A3BlastGate', 'A3BlastGate_Prefab', 'iVAC_Serial_006', '2025-07-11');

DECLARE @TypeToolStatus INT = (SELECT Id FROM Type WHERE Nom = 'EquipmentMode');
DECLARE @TypeGateStatus INT = (SELECT Id FROM Type WHERE Nom = 'DoorState');
DECLARE @TypePosition INT = (SELECT Id FROM Type WHERE Nom = 'Position');
DECLARE @TypeAngle INT = (SELECT Id FROM Type WHERE Nom = 'Angle');

--A1ToolPlus
INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A1ToolPlus'), 'A1ToolStatus', 'A1ToolPlus', @TypeToolStatus);
DECLARE @VarA1ToolStatus INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarA1ToolStatus, 'OFF', CURRENT_TIMESTAMP);

--A2ToolPlus
INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A2ToolPlus'), 'A2ToolStatus', 'A2ToolPlus', @TypeToolStatus);
DECLARE @VarA2ToolStatus INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarA2ToolStatus, 'ON', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A2ToolPlus'), 'SpindlePositionX', 'SpindlePositionX', @TypePosition);
DECLARE @VarSpindlePosX INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarSpindlePosX, '2.5', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A2ToolPlus'), 'SpindlePositionY', 'SpindlePositionY', @TypePosition);
DECLARE @VarSpindlePosY INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarSpindlePosY, '0.0', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A2ToolPlus'), 'SpindlePositionZ', 'SpindlePositionZ', @TypePosition);
DECLARE @VarSpindlePosZ INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarSpindlePosZ, '1.2', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A2ToolPlus'), 'SpindleAngleX', 'SpindleAngleX', @TypeAngle);
DECLARE @VarSpindleAngleX INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarSpindleAngleX, '0.0', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A2ToolPlus'), 'SpindleAngleY', 'SpindleAngleY', @TypeAngle);
DECLARE @VarSpindleAngleY INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarSpindleAngleY, '0.0', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A2ToolPlus'), 'SpindleAngleZ', 'SpindleAngleZ', @TypeAngle);
DECLARE @VarSpindleAngleZ INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarSpindleAngleZ, '0.0', CURRENT_TIMESTAMP);

--A3ToolPlus
INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A3ToolPlus'), 'A3ToolStatus', 'A3ToolPlus', @TypeToolStatus);
DECLARE @VarA3ToolStatus INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarA3ToolStatus, 'OFF', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A3ToolPlus'), 'LathePositionX', 'LathePositionX', @TypePosition);
DECLARE @VarLathePosX INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarLathePosX, '3.5', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A3ToolPlus'), 'LathePositionY', 'LathePositionY', @TypePosition);
DECLARE @VarLathePosY INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarLathePosY, '0.0', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A3ToolPlus'), 'LathePositionZ', 'LathePositionZ', @TypePosition);
DECLARE @VarLathePosZ INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarLathePosZ, '1.2', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A3ToolPlus'), 'LatheAngleX', 'LatheAngleX', @TypeAngle);
DECLARE @VarLatheAngleX INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarLatheAngleX, '0.0', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A3ToolPlus'), 'LatheAngleY', 'LatheAngleY', @TypeAngle);
DECLARE @VarLatheAngleY INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarLatheAngleY, '0.0', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A3ToolPlus'), 'LatheAngleZ', 'LatheAngleZ', @TypeAngle);
DECLARE @VarLatheAngleZ INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarLatheAngleZ, '0.0', CURRENT_TIMESTAMP);

--A1BlastGate
INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A1BlastGate'), 'A1BlastGateStatus', 'A1BlastGate', @TypeGateStatus);
DECLARE @VarA1BlastGate INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarA1BlastGate, 'OPEN', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A1BlastGate'), 'A1GatePositionX', 'A1GatePositionX', @TypePosition);
DECLARE @VarA1GatePosX INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarA1GatePosX, '2.5', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A1BlastGate'), 'A1GatePositionY', 'A1GatePositionY', @TypePosition);
DECLARE @VarA1GatePosY INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarA1GatePosY, '1.0', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A1BlastGate'), 'A1GatePositionZ', 'A1GatePositionZ', @TypePosition);
DECLARE @VarA1GatePosZ INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarA1GatePosZ, '1.2', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A1BlastGate'), 'A1GateAngleX', 'A1GateAngleX', @TypeAngle);
DECLARE @VarA1GateAngleX INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarA1GateAngleX, '0.0', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A1BlastGate'), 'A1GateAngleY', 'A1GateAngleY', @TypeAngle);
DECLARE @VarA1GateAngleY INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarA1GateAngleY, '0.0', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A1BlastGate'), 'A1GateAngleZ', 'A1GateAngleZ', @TypeAngle);
DECLARE @VarA1GateAngleZ INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarA1GateAngleZ, '0.0', CURRENT_TIMESTAMP);

--A2BlastGate
INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A2BlastGate'), 'A2BlastGateStatus', 'A2BlastGate', @TypeGateStatus);
DECLARE @VarA2BlastGate INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarA2BlastGate, 'OPEN', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A2BlastGate'), 'A2GatePositionX', 'A2GatePositionX', @TypePosition);
DECLARE @VarA2GatePosX INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarA2GatePosX, '2.5', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A2BlastGate'), 'A2GatePositionY', 'A2GatePositionY', @TypePosition);
DECLARE @VarA2GatePosY INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarA2GatePosY, '1.0', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A2BlastGate'), 'A2GatePositionZ', 'A2GatePositionZ', @TypePosition);
DECLARE @VarA2GatePosZ INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarA2GatePosZ, '1.2', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A2BlastGate'), 'A2GateAngleX', 'A2GateAngleX', @TypeAngle);
DECLARE @VarA2GateAngleX INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarA2GateAngleX, '0.0', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A2BlastGate'), 'A2GateAngleY', 'A2GateAngleY', @TypeAngle);
DECLARE @VarA2GateAngleY INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarA2GateAngleY, '0.0', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A2BlastGate'), 'A2GateAngleZ', 'A2GateAngleZ', @TypeAngle);
DECLARE @VarA2GateAngleZ INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarA2GateAngleZ, '0.0', CURRENT_TIMESTAMP);

--A3BlastGate
INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A3BlastGate'), 'A3BlastGateStatus', 'A3BlastGate', @TypeGateStatus);
DECLARE @VarA3BlastGate INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarA3BlastGate, 'CLOSED', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A3BlastGate'), 'A3GatePositionX', 'A3GatePositionX', @TypePosition);
DECLARE @VarA3GatePosX INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarA3GatePosX, '2.5', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A3BlastGate'), 'A3GatePositionY', 'A3GatePositionY', @TypePosition);
DECLARE @VarA3GatePosY INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarA3GatePosY, '1.0', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A3BlastGate'), 'A3GatePositionZ', 'A3GatePositionZ', @TypePosition);
DECLARE @VarA3GatePosZ INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarA3GatePosZ, '1.2', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A3BlastGate'), 'A3GateAngleX', 'A3GateAngleX', @TypeAngle);
DECLARE @VarA3GateAngleX INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarA3GateAngleX, '0.0', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A3BlastGate'), 'A3GateAngleY', 'A3GateAngleY', @TypeAngle);
DECLARE @VarA3GateAngleY INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarA3GateAngleY, '0.0', CURRENT_TIMESTAMP);

INSERT INTO Variable (EquipmentId, Nom, DataItemId, TypeId)
VALUES ((SELECT Id FROM Equipment WHERE Nom = 'A3BlastGate'), 'A3GateAngleZ', 'A3GateAngleZ', @TypeAngle);
DECLARE @VarA3GateAngleZ INT = SCOPE_IDENTITY();

INSERT INTO Data (VariableId, Value, Timestamp)
VALUES (@VarA3GateAngleZ, '0.0', CURRENT_TIMESTAMP);