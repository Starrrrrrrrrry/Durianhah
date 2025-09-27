// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Roles.sol";

contract IoTData {
    Roles public rolesContract;
    
    // IoT数据结构
    struct IoTDataPoint {
        uint256 timestamp;
        int256 temperature;    // 温度 (0.1°C精度)
        uint256 humidity;      // 湿度 (0.1%精度)
        uint256 soilMoisture;  // 土壤湿度
        uint256 soilPH;        // 酸碱度 (0.1精度)
        int256 gpsLatitude;    // GPS纬度 * 10^6
        int256 gpsLongitude;   // GPS经度 * 10^6
        uint256 lightIntensity; // 光照强度
        uint256 co2Level;      // CO2浓度
        string additionalData; // 其他数据
    }
    
    // 各阶段的IoT数据集
    struct IoTDataSet {
        IoTDataPoint[] dataPoints;
        uint256 averageScore;
        uint256 dataCount;
    }
    
    // 阶段定义
    uint8 constant PLANTATION_PHASE = 1;
    uint8 constant HARVEST_PHASE = 2;
    uint8 constant PACKING_PHASE = 3;
    uint8 constant QA_PHASE = 4;
    uint8 constant LOGISTICS_PHASE = 5;
    uint8 constant RETAIL_PHASE = 6;
    
    mapping(uint256 => mapping(uint8 => IoTDataSet)) public phaseIoTData;
    mapping(uint256 => uint8) public currentPhase;
    
    event IoTDataRecorded(uint256 tokenId, uint8 phase, uint256 dataScore, uint256 timestamp);
    event DataQualityAlert(uint256 tokenId, uint8 phase, string alertType);

    constructor(address _rolesContract) {
        rolesContract = Roles(_rolesContract);
    }
    
    modifier onlySupplyChainMember() {
        require(rolesContract.hasSupplyChainRole(msg.sender), "Not a supply chain member");
        _;
    }
    
    function recordPlantationData(
        uint256 tokenId,
        int256 temperature,
        uint256 humidity,
        uint256 soilMoisture,
        uint256 soilPH,
        int256 gpsLatitude,
        int256 gpsLongitude,
        uint256 lightIntensity,
        uint256 co2Level,
        string memory additionalData
    ) public onlySupplyChainMember returns (uint256) {
        require(rolesContract.hasRole(rolesContract.FARMER_ROLE(), msg.sender), "Only farmers can record plantation data");
        
        IoTDataPoint memory newData = IoTDataPoint({
            timestamp: block.timestamp,
            temperature: temperature,
            humidity: humidity,
            soilMoisture: soilMoisture,
            soilPH: soilPH,
            gpsLatitude: gpsLatitude,
            gpsLongitude: gpsLongitude,
            lightIntensity: lightIntensity,
            co2Level: co2Level,
            additionalData: additionalData
        });
        
        phaseIoTData[tokenId][PLANTATION_PHASE].dataPoints.push(newData);
        phaseIoTData[tokenId][PLANTATION_PHASE].dataCount++;
        
        uint256 dataScore = _calculatePlantationDataQuality(newData);
        phaseIoTData[tokenId][PLANTATION_PHASE].averageScore = (
            (phaseIoTData[tokenId][PLANTATION_PHASE].averageScore * (phaseIoTData[tokenId][PLANTATION_PHASE].dataCount - 1) + dataScore) 
            / phaseIoTData[tokenId][PLANTATION_PHASE].dataCount
        );
        
        currentPhase[tokenId] = PLANTATION_PHASE;
        
        emit IoTDataRecorded(tokenId, PLANTATION_PHASE, dataScore, block.timestamp);
        return dataScore;
    }
    
    function recordHarvestData(
        uint256 tokenId,
        int256 temperature,
        uint256 humidity,
        int256 gpsLatitude,
        int256 gpsLongitude,
        uint256 fruitMaturity,
        uint256 sugarContent,
        string memory additionalData
    ) public onlySupplyChainMember returns (uint256) {
        require(rolesContract.hasRole(rolesContract.FARMER_ROLE(), msg.sender), "Only farmers can record harvest data");
        
        IoTDataPoint memory newData = IoTDataPoint({
            timestamp: block.timestamp,
            temperature: temperature,
            humidity: humidity,
            soilMoisture: 0, // 收获阶段不需要土壤数据
            soilPH: 0,
            gpsLatitude: gpsLatitude,
            gpsLongitude: gpsLongitude,
            lightIntensity: fruitMaturity,
            co2Level: sugarContent,
            additionalData: additionalData
        });
        
        phaseIoTData[tokenId][HARVEST_PHASE].dataPoints.push(newData);
        phaseIoTData[tokenId][HARVEST_PHASE].dataCount++;
        
        uint256 dataScore = _calculateHarvestDataQuality(newData);
        phaseIoTData[tokenId][HARVEST_PHASE].averageScore = (
            (phaseIoTData[tokenId][HARVEST_PHASE].averageScore * (phaseIoTData[tokenId][HARVEST_PHASE].dataCount - 1) + dataScore) 
            / phaseIoTData[tokenId][HARVEST_PHASE].dataCount
        );
        
        currentPhase[tokenId] = HARVEST_PHASE;
        
        emit IoTDataRecorded(tokenId, HARVEST_PHASE, dataScore, block.timestamp);
        return dataScore;
    }
    
    function recordTransportData(
        uint256 tokenId,
        int256 temperature,
        uint256 humidity,
        int256 gpsLatitude,
        int256 gpsLongitude,
        uint256 vibrationLevel,
        uint256 tiltAngle,
        string memory additionalData
    ) public onlySupplyChainMember returns (uint256) {
        require(rolesContract.hasRole(rolesContract.LOGISTICS_ROLE(), msg.sender), "Only logistics can record transport data");
        
        IoTDataPoint memory newData = IoTDataPoint({
            timestamp: block.timestamp,
            temperature: temperature,
            humidity: humidity,
            soilMoisture: vibrationLevel,
            soilPH: tiltAngle,
            gpsLatitude: gpsLatitude,
            gpsLongitude: gpsLongitude,
            lightIntensity: 0,
            co2Level: 0,
            additionalData: additionalData
        });
        
        phaseIoTData[tokenId][LOGISTICS_PHASE].dataPoints.push(newData);
        phaseIoTData[tokenId][LOGISTICS_PHASE].dataCount++;
        
        uint256 dataScore = _calculateTransportDataQuality(newData);
        phaseIoTData[tokenId][LOGISTICS_PHASE].averageScore = (
            (phaseIoTData[tokenId][LOGISTICS_PHASE].averageScore * (phaseIoTData[tokenId][LOGISTICS_PHASE].dataCount - 1) + dataScore) 
            / phaseIoTData[tokenId][LOGISTICS_PHASE].dataCount
        );
        
        // 温度监控警报
        if (temperature > 80) { // 高于8°C
            emit DataQualityAlert(tokenId, LOGISTICS_PHASE, "HIGH_TEMPERATURE");
        }
        
        // 震动监控警报
        if (vibrationLevel > 500) { // 高震动
            emit DataQualityAlert(tokenId, LOGISTICS_PHASE, "HIGH_VIBRATION");
        }
        
        currentPhase[tokenId] = LOGISTICS_PHASE;
        
        emit IoTDataRecorded(tokenId, LOGISTICS_PHASE, dataScore, block.timestamp);
        return dataScore;
    }
    
    function _calculatePlantationDataQuality(IoTDataPoint memory data) private pure returns (uint256) {
        uint256 score = 100;
        
        // 温度合理性检查 (榴莲适宜温度: 24-30°C)
        if (data.temperature < 240 || data.temperature > 300) {
            score -= 30;
        }
        
        // 湿度合理性检查 (60-90%)
        if (data.humidity < 600 || data.humidity > 900) {
            score -= 20;
        }
        
        // 土壤pH合理性 (榴莲适宜pH: 5.0-6.5)
        if (data.soilPH < 50 || data.soilPH > 65) {
            score -= 25;
        }
        
        // GPS数据完整性
        if (data.gpsLatitude == 0 || data.gpsLongitude == 0) {
            score -= 15;
        }
        
        return score > 0 ? score : 0;
    }
    
    function _calculateHarvestDataQuality(IoTDataPoint memory data) private pure returns (uint256) {
        uint256 score = 100;
        
        // 收获时温度检查
        if (data.temperature < 220 || data.temperature > 320) {
            score -= 25;
        }
        
        // 成熟度检查 (假设成熟度50-100为合理)
        if (data.lightIntensity < 50) {
            score -= 30;
        }
        
        // 糖度检查 (假设糖度10-25为合理)
        if (data.co2Level < 100 || data.co2Level > 250) {
            score -= 20;
        }
        
        return score > 0 ? score : 0;
    }
    
    function _calculateTransportDataQuality(IoTDataPoint memory data) private pure returns (uint256) {
        uint256 score = 100;
        
        // 运输温度检查 (榴莲运输适宜温度: 4-8°C)
        if (data.temperature < 35 || data.temperature > 80) {
            score -= 40;
        }
        
        // 湿度检查
        if (data.humidity < 700 || data.humidity > 900) {
            score -= 20;
        }
        
        // 震动水平检查
        if (data.soilMoisture > 300) { // 震动过大
            score -= 25;
        }
        
        // 倾斜角度检查
        if (data.soilPH > 150) { // 倾斜角度过大
            score -= 15;
        }
        
        return score > 0 ? score : 0;
    }
    
    function getPhaseIoTData(uint256 tokenId, uint8 phase) public view returns (IoTDataSet memory) {
        return phaseIoTData[tokenId][phase];
    }
    
    function getCurrentDataScore(uint256 tokenId) public view returns (uint256) {
        uint8 phase = currentPhase[tokenId];
        if (phase == 0) return 0;
        return phaseIoTData[tokenId][phase].averageScore;
    }
    
    function getDataPointsCount(uint256 tokenId, uint8 phase) public view returns (uint256) {
        return phaseIoTData[tokenId][phase].dataCount;
    }
}