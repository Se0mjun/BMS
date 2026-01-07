%% BMS 모델 비교 시뮬레이션: 선형(Linear) vs 비선형(Non-linear) 모델
% 작성일: 2026.01.07
% 설명: 이상적인 직선 모델과 실제 배터리 특성(S자 곡선)을 한 그래프에서 비교 분석

clear all; clc; close all; % 작업 공간 초기화 (변수 삭제, 명령창 청소, 그래프 닫기)

%% 1. 파라미터 설정 (Parameter Setting)
Capacity = 2.0;    % 배터리 용량 [Ah]
SOC_init = 1.0;    % 초기 SOC (100% 충전 상태)
dt = 1;            % 샘플링 시간 [초]
R0 = 0.05;         % 배터리 내부 저항 [Ohm]
Time = 0:dt:3600;  % 시뮬레이션 시간 (1시간)

% 입력 전류 생성 (2A 정전류 방전)
Current = 2 * ones(size(Time)); 

%% 2. 메모리 할당 (Memory Allocation) - 비교를 위해 변수 분리
% 속도 최적화를 위해 zeros로 공간을 미리 확보합니다.
SOC = zeros(size(Time)); 

% [핵심 변경] 두 가지 모델을 비교해야 하므로 전압 저장 공간을 각각 따로 만듭니다.
Voltage_Lin    = zeros(size(Time)); % 모델 1: 단순 직선 모델용 결과 저장
Voltage_NonLin = zeros(size(Time)); % 모델 2: 정밀 비선형 모델용 결과 저장

%% 3. 초기값 설정 (Initialization)
SOC(1) = SOC_init;

% (1) 선형 모델(Linear)의 초기 전압 계산
% 수식: OCV = 3.0 + 1.2 * SOC (단순 1차 함수)
OCV_Lin_Start = 3.0 + 1.2 * SOC_init;
Voltage_Lin(1) = OCV_Lin_Start - Current(1) * R0;

% (2) 비선형 모델(Non-linear)의 초기 전압 계산
% 수식: 실제 리튬이온 배터리의 화학적 특성 반영 (지수함수 + 분수함수)
OCV_NonLin_Start = 3.2 + 0.5*SOC_init - 0.1./(SOC_init+0.1) + 0.2*exp(5*(SOC_init-1));
Voltage_NonLin(1) = OCV_NonLin_Start - Current(1) * R0;

%% 4. 루프 시뮬레이션 (Loop Simulation)
for k = 2:length(Time)
    
    % (1) SOC 계산: 전류 적산법 (공통 사용)
    % 어떤 전압 모델을 쓰든, 흘러나간 전류량(SOC)은 물리적으로 동일합니다.
    SOC(k) = SOC(k-1) - (Current(k) * dt) / (Capacity * 3600);
    
    % (2) 모델 1: 선형 모델 (Linear Model) 계산
    % 특징: 계산이 빠르고 단순하지만, 실제 배터리 거동과 오차가 큼
    OCV_Lin = 3.0 + 1.2 * SOC(k);
    Voltage_Lin(k) = OCV_Lin - Current(k) * R0;
    
    % (3) 모델 2: 비선형 모델 (Non-linear Model) 계산
    % 특징: 실제 배터리의 'Plateau(평탄 구간)'와 'Cut-off(급락 구간)'를 모사함
    % 수식 설명:
    %  - 3.2 + 0.5*SOC : 기본 기울기
    %  - 0.1./(SOC+0.1): SOC가 0에 가까워질 때 전압 급락 (방전 종지)
    %  - 0.2*exp(...)  : SOC가 1에 가까울 때 전압 상승 (완충 구간)
    OCV_NonLin = 3.2 + 0.5*SOC(k) - 0.1./(SOC(k)+0.1) + 0.2*exp(5*(SOC(k)-1));
    Voltage_NonLin(k) = OCV_NonLin - Current(k) * R0;
    
end

%% 5. 결과 그래프 출력 (Comparison Plot)
figure(1); 

% 첫 번째 그래프: SOC 변화 (공통)
subplot(2,1,1);
plot(Time, SOC, 'k', 'LineWidth', 1.5); % 검은색('k') 실선
grid on;              
xlabel('Time [sec]'); 
ylabel('SOC [-]');    
title('State of Charge (SOC) Change');
ylim([-0.1 1.1]);     

% 두 번째 그래프: 전압 비교 (여기가 시뮬레이션의 핵심 결과!)
subplot(2,1,2);

% [Step 1] 선형 모델 그리기 (파란색 점선)
plot(Time, Voltage_Lin, 'b--', 'LineWidth', 1.5); 
hold on; % [중요] 기존 그래프를 지우지 않고 유지하는 명령어 (겹쳐 그리기 필수)

% [Step 2] 비선형 모델 그리기 (빨간색 실선)
plot(Time, Voltage_NonLin, 'r-', 'LineWidth', 1.5); 

grid on;
title('Terminal Voltage Comparison: Ideal vs Real');
xlabel('Time [sec]'); 
ylabel('Voltage [V]');

% [Step 3] 범례(Legend) 추가
% 그래프에 그려진 순서대로 이름을 붙여줍니다.
legend('Linear Model (Simple)', 'Non-linear Model (Real-like)', 'Location', 'SouthWest');

hold off; % 겹쳐 그리기 모드 해제
