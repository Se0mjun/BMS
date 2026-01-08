%% BMS 로직: 패시브 셀 밸런싱 (Passive Balancing) 시뮬레이션
% 작성일: 2026.01.08
% 설명: 4직렬(4S) 배터리 팩에서 전압이 높은 셀을 방전시켜 균형을 맞춤
clear all; clc; close all;

%% 1. 파라미터 설정
NumCells = 4;           % 셀 개수
Capacity = 2.0;         % 용량 [Ah]
R_bleed = 10;           % 밸런싱 저항 (10 Ohm) -> 전류 = V/R
Balance_Thresh = 0.01;  % 밸런싱 동작 기준 전압 차이 (10mV)
dt = 1;                 % 시간 간격
Time = 0:dt:1800;       % 30분 시뮬레이션

%% 2. 초기 상태 설정 (불균형 상태 생성)
% 각 셀의 초기 SOC를 다르게 설정합니다.
SOCs = [0.80; 0.82; 0.79; 0.85]; % 4번 셀이 가장 높음 -> 밸런싱 대상
SOC_History = zeros(NumCells, length(Time));
Voltage_History = zeros(NumCells, length(Time));
Balancing_Status = zeros(NumCells, length(Time)); % 스위치 On/Off 상태 저장

%% 3. 루프 시뮬레이션 (Time-Stepping Loop)
% k는 현재 시뮬레이션의 시간 단계(Step)를 의미합니다.
for k = 1:length(Time)
    
    % (1) 각 셀의 전압(OCV) 계산
    % [설명] 시뮬레이션을 위해 SOC로부터 전압을 역산합니다.
    % 실제 BMS에서는 전압 센서(ADC)가 읽어오는 값이지만, 여기서는 모델이므로 수식으로 만듭니다.
    % 간단한 선형 모델 가정: V = 3.0 + (1.0 * SOC)
    % 예: SOC 0.8(80%) -> 3.8V
    Voltages = 3.0 + 1.0 * SOCs; 
    
    % (2) 밸런싱 로직 판단 (Control Logic)
    
    % [Step A] "기준점" 찾기 (Target Voltage)
    % 패시브 밸런싱은 '하향 평준화'이므로, 가장 낮은 전압을 가진 셀이 기준이 됩니다.
    % 나머지 모든 셀을 이 Min_V에 맞춰야 하기 때문입니다.
    Min_V = min(Voltages);
    
    % [Step B] 밸런싱 전류 초기화
    % 이번 턴(k)에 흘릴 밸런싱 전류를 저장할 임시 변수입니다. (기본 0A)
    Bleeding_Current = zeros(NumCells, 1);
    
    % [Step C] 각 셀별로 검사 (개별 제어)
    for i = 1:NumCells
        
        % [조건문 핵심] "내가 기준(최소값)보다 의미 있게 높은가?"
        % Balance_Thresh(0.01V)는 '히스테리시스' 역할을 합니다.
        % 아주 미세한 차이(노이즈 등)로 스위치가 타다닥거리는 것을 방지하기 위함입니다.
        if Voltages(i) > (Min_V + Balance_Thresh)
            
            % [Action: ON] 밸런싱 스위치 켬 -> 방전 시작
            % 옴의 법칙: I = V / R
            % 저항(R_bleed)을 통해 전압(Voltages(i))에 비례하는 전류가 빠져나갑니다.
            Bleeding_Current(i) = Voltages(i) / R_bleed; 
            
            % 그래프 확인용 플래그 (1: 밸런싱 중)
            Balancing_Status(i, k) = 1; 
            
        else
            
            % [Action: OFF] 밸런싱 스위치 끔 -> 전류 흐르지 않음
            % 기준 전압과 비슷하거나(차이가 작거나), 가장 낮은 셀인 경우입니다.
            Bleeding_Current(i) = 0;
            
            % 그래프 확인용 플래그 (0: 대기 중)
            Balancing_Status(i, k) = 0;
        end
    end
    
    % (3) 물리적 상태 업데이트 (SOC Update)
    % [설명] 전류 적산법(Ampere Counting)으로 빠져나간 전류만큼 SOC를 감소시킵니다.
    % SOC_new = SOC_old - (전류 * 시간 / 전체용량)
    % Bleeding_Current가 0인 셀(밸런싱 OFF)은 SOC가 변하지 않습니다.
    % * 3600을 나누는 이유: Capacity는 [Ah] 단위, dt는 [sec] 단위라서 시간을 맞춰주기 위함입니다.
    SOCs = SOCs - (Bleeding_Current * dt) / (Capacity * 3600);
    
    % (4) 데이터 로깅 (Data Logging)
    % 나중에 그래프를 그리기 위해 현재 상태를 역사(History) 배열에 기록합니다.
    SOC_History(:, k) = SOCs;
    Voltage_History(:, k) = Voltages;
    
end

%% 4. 결과 그래프
figure(3);
subplot(3,1,1);
plot(Time, Voltage_History, 'LineWidth', 1.5);
title('Cell Voltages (Balancing Process)');
ylabel('Voltage [V]'); grid on;
legend('Cell 1', 'Cell 2', 'Cell 3', 'Cell 4');

subplot(3,1,2);
plot(Time, SOC_History, 'LineWidth', 1.5);
title('Cell SOC Convergence');
ylabel('SOC [-]'); grid on;

subplot(3,1,3);
% 스위치 On/Off 상태를 이미지처럼 표현
imagesc(Balancing_Status);
colormap(gray); % 흰색=1(ON), 검은색=0(OFF) - 반전시킬수 있음
title('Balancing Switch Status (White=ON, Black=OFF)');
xlabel('Time [sec]'); ylabel('Cell Number');
yticks([1 2 3 4]);
