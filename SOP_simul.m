%% BMS 핵심: SOP (State of Power) 산출 시뮬레이션
% 작성일: 2026.01.08
% 설명: "지금 엑셀을 밟았을 때 배터리가 뻗지 않고 견딜 수 있는 최대 파워는?"

clear all; clc; close all;

%% 1. 파라미터 설정 (배터리 스펙 및 안전 기준)

% (1) 배터리 셀의 물리적 스펙
Capacity = 2.0;         % [Ah] 18650 원통형 배터리 1개의 표준 용량 (보통 2000~3000mAh)
dt = 1;                 % [sec] BMS가 연산하는 주기 (1초마다 상태 체크)
Time = 0:dt:2500;       % 시뮬레이션 시간 (약 40분 정도 주행한다고 가정)

% (2) 안전을 위한 전압 제한 (Safety Limits - Chemistry)
% 리튬이온 배터리는 이 전압 범위를 벗어나면 화재가 나거나 벽돌(고장)이 됩니다.
V_max = 4.2;            % [V] 충전 상한선: 이 위로 올라가면 전해액 분해/가스 발생 -> 폭발 위험
V_min = 2.5;            % [V] 방전 하한선: 이 밑으로 내려가면 구리 집전체 용해 -> 배터리 영구 손상
                        % 즉, SOP 로직의 목표는 "무슨 짓을 해도 2.5V 밑으로 안 떨어지게 막는 것"입니다.

% (3) 하드웨어적 전류 제한 (Hardware Constraints)
% 배터리 자체는 100A를 낼 수 있어도, 전선이나 퓨즈가 못 버티면 불이 납니다.
I_hardware_limit = 10;  % [A] 퓨즈(Fuse)나 케이블, 릴레이가 견딜 수 있는 허용 전류
                        % SOP는 '배터리 능력'과 '부품 한계' 중 더 낮은 값을 따릅니다.

% (4) 현재 배터리 상태 (Initial State)
R0 = 0.1;               % [Ohm] 배터리 내부 저항 (DCIR)
                        % 중요: 저항이 클수록 전류를 조금만 써도 전압이 팍 떨어집니다(V drop = I*R).
                        % 즉, 배터리가 늙거나(SOH 감소) 추운 날에는 R0가 커져서 SOP(출력)가 줄어듭니다.
SOC_init = 1.0;         % 초기에는 100% 완충 상태에서 출발

%% 2. 메모리 할당 (Memory Allocation)
% MATLAB 코딩의 필수 테크닉입니다.
% for문을 돌면서 배열 크기를 계속 늘리면(동적 할당) 컴퓨터가 메모리를 뺐다 꼈다 하느라 엄청 느려집니다.
% 그래서 zeros 명령어로 "앞으로 이만큼 데이터가 들어올 거니까 방 2501개 미리 비워놔"라고 선언하는 겁니다.
SOC = zeros(size(Time));
SOC(1) = SOC_init;

% 데이터 로깅용 변수들
Log_I_max_dis = zeros(size(Time)); % "지금 최대 몇 A까지 가능해?" (전류 제한값)
Log_P_max_dis = zeros(size(Time)); % "지금 최대 몇 Watt까지 가능해?" (파워 제한값)
Log_Voltage   = zeros(size(Time)); % 전압 모니터링

% [시나리오 설정]
% 운전자가 시종일관 2A의 전류(약 1C 방전)로 계속 달린다고 가정합니다.
Current_Load = 2 * ones(size(Time)); 

%% 3. 루프 시뮬레이션 (Main Loop)
for k = 1:length(Time)
    
    % (1) 현재 SOC 업데이트 (전류 적산법)
    if k > 1
        % 지난번 SOC에서 이번에 쓴 전류만큼 뺍니다.
        SOC(k) = SOC(k-1) - (Current_Load(k) * dt) / (Capacity * 3600);
    end
    
    % (2) 현재 OCV(개방회로전압) 계산
    % 배터리 잔량(SOC)에 따라 기본 전압(OCV)이 변합니다. (SOC가 낮으면 OCV도 낮아짐)
    OCV_now = 3.2 + 0.5*SOC(k) - 0.1./(SOC(k)+0.01) + 0.2*exp(5*(SOC(k)-1));
    
    % (3) 현재 단자 전압 계산
    % V = OCV - I*R (부하가 걸리면 저항 때문에 전압이 떨어짐)
    Log_Voltage(k) = OCV_now - Current_Load(k) * R0;
    
    %% [핵심 로직] SOP (State of Power) 계산
    % 목적: "전압이 V_min(2.5V)에 닿을락 말락 할 때의 전류(I_max)는?"
    
    % [Step 1] 전압 제약에 의한 전류 한계 (Battery Capability)
    % 수식 유도: V_min = OCV - I_max * R0
    %           I_max * R0 = OCV - V_min
    %           I_max = (OCV - V_min) / R0
    % 의미: (현재 OCV - 바닥 전압) = "내가 쓸 수 있는 전압 여유분(Voltage Margin)"
    % 이 여유분을 저항(R0)으로 나누면 흘릴 수 있는 최대 전류가 나옵니다.
    I_limit_volt = (OCV_now - V_min) / R0;
    
    % [Step 2] 하드웨어 제약 적용 (System Limit)
    % 배터리 계산상 50A가 나와도, 퓨즈가 10A짜리면 10A밖에 못 씁니다.
    % min 함수를 써서 둘 중 더 안전한(작은) 값을 선택합니다.
    I_discharge_capability = min(I_limit_volt, I_hardware_limit);
    
    % [예외 처리] 음수 방지
    % 배터리를 너무 많이 써서 OCV 자체가 2.5V 밑으로 떨어지면?
    % 전류를 아예 못 쓰게(0A) 막아야 합니다.
    if I_discharge_capability < 0
        I_discharge_capability = 0;
    end
    
    % [Step 3] 최종 SOP 파워 계산 [Watt]
    % Power = Voltage * Current
    % 최대 전류를 흘리는 순간, 전압은 V_min(2.5V)까지 떨어져 있을 것입니다.
    % 따라서 P_max = 2.5V * 최대전류
    P_discharge_max = V_min * I_discharge_capability;
    
    % (4) 데이터 저장
    Log_I_max_dis(k) = I_discharge_capability;
    Log_P_max_dis(k) = P_discharge_max;
    
end

%% 4. 결과 그래프 출력
figure(1);

% 첫 번째 그래프: SOC 감소 확인
subplot(3,1,1);
plot(Time, SOC*100, 'k', 'LineWidth', 1.5);
ylabel('SOC [%]'); grid on;
title('1. Battery Draining (SOC Decrease)');

% 두 번째 그래프: SOP 전류 제한
subplot(3,1,2);
plot(Time, Log_I_max_dis, 'b', 'LineWidth', 1.5);
hold on;
% 빨간 점선: 하드웨어(퓨즈) 한계선 그리기
yline(I_hardware_limit, 'r--', 'Hardware Limit (10A)');
ylabel('Max Current [A]'); grid on;
title('2. Max Discharge Current Capability');
legend('Calculated I_{max}', 'Fuse Limit');

% 세 번째 그래프: SOP 파워 제한 vs 실제 사용량
subplot(3,1,3);
Actual_Power = Log_Voltage .* Current_Load; % 내가 실제로 쓰고 있는 파워
plot(Time, Log_P_max_dis, 'r', 'LineWidth', 2); hold on; % SOP (천장)
plot(Time, Actual_Power, 'g--', 'LineWidth', 1);        % 실제 (바닥)
ylabel('Power [Watt]'); xlabel('Time [sec]');
grid on;
title('3. SOP (State of Power) vs Actual Load');
legend('SOP (Max Limit)', 'Actual Used Power');

% [그래프 해석 가이드]
% 1. 시뮬레이션 초반 (~1500초):
%    - 파란선(계산된 전류)이 10A보다 훨씬 높지만, 
%    - 빨간 점선(퓨즈 10A) 때문에 SOP는 10A로 잘립니다 (플랫한 구간).
% 2. 시뮬레이션 후반 (1500초~):
%    - 배터리 전압이 떨어지면서 "전압 여유분"이 부족해집니다.
%    - 이제는 퓨즈가 문제가 아니라 배터리 자체가 힘이 빠져서
%    - 파란선(SOP)이 10A 밑으로 급격히 떨어집니다. (이때가 출력 제한이 걸리는 시점)
