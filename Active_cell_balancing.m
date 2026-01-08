%% BMS 로직: 액티브 셀 밸런싱 (Active Balancing - Energy Transfer)
% 작성일: 2026.01.08
% 설명: 가장 전압이 높은 셀의 에너지를 빼서, 가장 낮은 셀에게 전달하는 로직
clear all; clc; close all;

%% 1. 파라미터 설정
NumCells = 4;           % 4직렬
Capacity = 2.0;         % 용량 2Ah
Balance_Thresh = 0.01;  % 10mV 이상 차이나면 밸런싱 시작
dt = 1;                 
Time = 0:dt:1800;       

% [액티브 밸런싱 핵심 파라미터]
Transfer_Current = 0.5; % 이동시킬 전류 (0.5A로 퍼 나른다고 가정)
Efficiency = 0.90;      % 에너지 전달 효율 (90%)
                        % 100을 보내면 가는 도중 10은 손실되고 90만 도착함

%% 2. 초기 상태 (불균형 심화)
% 1번은 배고프고(Low), 4번은 배부른(High) 상태
SOCs = [0.70; 0.80; 0.80; 0.90]; 
SOC_History = zeros(NumCells, length(Time));
Voltage_History = zeros(NumCells, length(Time));

%% 3. 루프 시뮬레이션
for k = 1:length(Time)
    
    % (1) 전압 계산 (선형 모델 가정)
    Voltages = 3.0 + 1.0 * SOCs;
    
    % (2) 밸런싱 로직 판단
    [Max_V, Max_Idx] = max(Voltages); % 제일 부자(Source) 찾기
    [Min_V, Min_Idx] = min(Voltages); % 제일 거지(Target) 찾기
    
    % 전류 벡터 초기화 (모든 셀 0A)
    I_balance = zeros(NumCells, 1);
    
    % (3) 밸런싱 실행 조건
    % "빈부격차가 허용치보다 크면 밸런싱을 수행한다"
    if (Max_V - Min_V) > Balance_Thresh
        
        % [Source: 주는 놈]
        % 전류가 나갑니다 (+ 부호: 방전)
        I_balance(Max_Idx) = Transfer_Current; 
        
        % [Target: 받는 놈]
        % 전류가 들어옵니다 (- 부호: 충전)
        % *주의: 보낸 만큼 다 못 받습니다. 효율(Efficiency)만큼만 들어옵니다.
        % 예: 0.5A 보냄 -> 0.45A 받음 (나머지는 열 손실)
        I_balance(Min_Idx) = - (Transfer_Current * Efficiency);
        
    end
    
    % (4) SOC 업데이트
    % SOC 감소량 = (전류 * 시간) / 용량
    % 주는 놈은 줄어들고, 받는 놈은 늘어납니다.
    SOCs = SOCs - (I_balance * dt) / (Capacity * 3600);
    
    % (5) 데이터 저장
    SOC_History(:, k) = SOCs;
    Voltage_History(:, k) = Voltages;
    
end

%% 4. 결과 그래프
figure(1);
subplot(2,1,1);
plot(Time, Voltage_History, 'LineWidth', 1.5);
title('Active Balancing: Voltage Convergence');
ylabel('Voltage [V]'); legend('Cell 1 (Low)', 'Cell 2', 'Cell 3', 'Cell 4 (High)');
grid on;

subplot(2,1,2);
plot(Time, SOC_History, 'LineWidth', 1.5);
title('Active Balancing: SOC Transfer');
xlabel('Time [sec]'); ylabel('SOC [-]');
grid on;

% [그래프 관전 포인트]
% 1. Cell 4(노란선)는 내려가고, Cell 1(파란선)은 올라옵니다.
% 2. Cell 2, 3은 가만히 있습니다 (중간층).
% 3. 결국 4개가 한 지점에서 만납니다.
% 4. 패시브와 달리, 전체 평균 SOC는 아주 조금만 감소합니다 (손실분만큼만).



% 주의사항
%위 코드는 **"논리적 시뮬레이션"**입니다. 실제 하드웨어인 **DC-DC 컨버터(벅-부스트 컨버터)**나 플라이백 트랜스포머의 복잡한 
%스위칭(PWM) 동작은 생략되어 있습니다.

%다음 단계 조언:

%이 코드를 돌려보시고 **"아, 높은 곳에서 낮은 곳으로 퍼 나르는구나"**라는 감을 잡으세요.

%진짜 **"전기회로적인 액티브 밸런싱"**을 하고 싶다면, 이제 .m 파일(스크립트)로는 너무 어렵습니다. 
%**Simulink (Simscape Electrical)**을 켜야 합니다. 거기에는 Inductor, MOSFET, Capacitor 블록이 다 있어서 선만 연결하면 됩니다.
