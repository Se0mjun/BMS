%% BMS 알고리즘: 확장 칼만 필터(EKF) 기반 SOC 추정
% 작성일: 2026.01.08
% 설명: 전류 적산법의 누적 오차와 센서 노이즈를 EKF로 보정하는 과정 시뮬레이션
clear all; clc; close all;

%% 1. 파라미터 설정
Capacity = 2.0;     % 배터리 용량 [Ah]
dt = 1;             % 샘플링 시간 [sec]
R0 = 0.05;          % 내부 저항 [Ohm]
Time = 0:dt:1000;   % 1000초 시뮬레이션

% 노이즈 설정 (시뮬레이션의 핵심)
Current_True = 2 * ones(size(Time));         % 실제 전류 (2A 방전)
Current_Meas = Current_True + 0.5 * randn(size(Time)); % 센서 측정 전류 (노이즈 포함)

%% 2. 초기화 및 메모리 할당 (Initialization & Pre-allocation)
% 시뮬레이션 루프(for문)가 돌기 전에 '출발점'을 정하고 '빈 노트'를 준비하는 단계입니다.

% (1) 시뮬레이션의 '정답' 초기값 설정 (True State)
% 배터리가 시뮬레이션 시작 시점에 100% 충전되어 있다고 가정합니다.
% 이 값은 루프 안에서 물리 법칙에 따라 계속 변합니다.
True_SOC = 1.0; 

% (2) 알고리즘의 '추정' 초기값 설정 (Initial Guess)
% 실제 배터리가 100%라도, BMS 알고리즘은 100%인지 모를 수도 있습니다.
% 하지만 여기서는 알고리즘도 "100%일 것이다"라고 알고 시작한다고 가정합니다.
Ah_SOC = 1.0;       % 전류 적산법: "지금 100%라고 치고 더하고 빼기 시작하자"
EKF_SOC = 1.0;      % EKF: "내 첫 추정값은 100%야"

% (3) EKF 전용 변수 초기화 (Algorithm Variables)
% P는 '오차 공분산'으로, "내가 추정한 값이 얼마나 틀릴 수 있는지"에 대한 불안감입니다.
% P = 0이면 "완벽하게 확신함", P가 크면 "잘 모르겠음"을 의미합니다.
% 처음엔 불확실하므로 0.1(10%) 정도의 불확실성을 가지고 시작합니다.
P = 0.1;            

% Q와 R은 칼만 필터의 성능을 결정하는 '튜닝 파라미터'입니다. (상수)
% 루프 밖에서 미리 정해두어야 계산에 사용됩니다.
Q = 1e-5;  % 프로세스 노이즈 공분산: "내 배터리 모델 수식(SOC 적분)을 얼마나 믿을까?" (작을수록 모델 신뢰)
R = 0.1;   % 측정 노이즈 공분산: "전압 센서 값을 얼마나 믿을까?" (클수록 센서 불신 = 노이즈가 많다고 가정)

% (4) 데이터 저장용 메모리 미리 확보 (Memory Pre-allocation)
% [중요] MATLAB에서 속도를 빠르게 하기 위한 필수 테크닉입니다.
% 루프를 돌 때마다 배열 크기를 늘리는 것은 비효율적이므로,
% zeros 명령어로 0이 채워진 긴 방(배열)을 미리 만들어둡니다.
Log_True_SOC = zeros(size(Time)); % 실제 SOC 기록용 빈 방
Log_Ah_SOC   = zeros(size(Time)); % 전류적산법 결과 기록용 빈 방
Log_EKF_SOC  = zeros(size(Time)); % EKF 결과 기록용 빈 방

%% 3. 루프 시뮬레이션 (Time-Stepping Loop)
for k = 1:length(Time)
    
    %% [A] 실제 세상 (Real World Simulation) - "우리가 모르는 정답"
    % (1) 실제 SOC 물리적 변화
    % 전류가 흐르면 배터리 안의 리튬 이온은 실제로 이동합니다. (진짜 물리 현상)
    True_SOC = True_SOC - (Current_True(k) * dt) / (Capacity * 3600);
    
    % (2) 실제 센서가 읽는 전압 (Real Voltage Measurement)
    % 실제 배터리 전압(OCV - IR)에 센서 노이즈(randn)가 섞여서 BMS로 들어옵니다.
    % BMS는 True_SOC를 절대 알 수 없고, 오직 이 'Voltage_Meas' 값만 볼 수 있습니다.
    OCV_True = 3.2 + 0.5*True_SOC - 0.1./(True_SOC+0.1) + 0.2*exp(5*(True_SOC-1));
    Voltage_Meas = OCV_True - Current_True(k)*R0 + 0.01*randn; 
    
    %% [B] BMS 알고리즘 1: 단순 전류 적산법 - "멍청한 계산기"
    % (1) 노이즈가 낀 전류를 그대로 더하고 뺍니다.
    % 센서가 0.1A 틀리면, 시간이 지날수록 오차가 산더미처럼 쌓입니다(Drift 현상).
    Ah_SOC = Ah_SOC - (Current_Meas(k) * dt) / (Capacity * 3600);
    
    %% [C] BMS 알고리즘 2: 확장 칼만 필터 (EKF) - "똑똑한 추정기"
    
    % --- 1단계: 예측 (Time Update / Prediction) ---
    % "전압 센서를 보기 전, 일단 전류 적산법으로 어디쯤인지 추측해보자."
    
    % (1) 상태 예측 (A Priori State Estimate)
    % 이전 SOC에서 전류만큼 빼서 '임시 SOC'를 계산합니다. (전류 적산법과 식은 동일)
    EKF_SOC_Pred = EKF_SOC - (Current_Meas(k) * dt) / (Capacity * 3600);
    
    % (2) 오차 공분산 예측 (A Priori Error Covariance)
    % 시간이 흘렀으므로(dt), 내 추측에 대한 불확실성(P)이 조금 더 커집니다(+Q).
    % Q는 '시스템 노이즈'로, 모델이 완벽하지 않음을 반영합니다.
    P_Pred = P + Q;
    
    
    % --- 2단계: 보정 (Measurement Update / Correction) ---
    % "이제 전압 센서 값을 보고, 아까 추측한 게 맞는지 확인해서 고치자."
    
    % (3) 예측 전압 계산 (Estimated Measurement)
    % "내가 추측한 SOC(EKF_SOC_Pred)가 맞다면, 전압은 몇 볼트가 나와야 할까?"
    OCV_Pred = 3.2 + 0.5*EKF_SOC_Pred - 0.1./(EKF_SOC_Pred+0.1) + 0.2*exp(5*(EKF_SOC_Pred-1));
    Voltage_Pred = OCV_Pred - Current_Meas(k)*R0;
    
    % (4) 잔차 계산 (Innovation)
    % "실제 센서값(Meas)과 내 예상값(Pred)이 얼마나 차이나지?"
    % 이 차이가 클수록 내 예측(SOC)이 많이 틀렸다는 뜻입니다.
    Innovation = Voltage_Meas - Voltage_Pred;
    
    % (5) 자코비안 계산 (H Matrix - Linearization)
    % "SOC가 조금 변할 때 전압은 얼마나 심하게 변하는가?" (기울기)
    % 비선형 OCV 곡선을 현재 위치에서 직선으로 근사화(미분)합니다.
    % 여기서는 계산 편의상 평균 기울기 0.5로 고정했지만, 실제론 수치미분을 씁니다.
    H = 0.5; 
    
    % (6) 칼만 이득 계산 (Kalman Gain, K) - [가장 중요]
    % "전압 센서를 얼마나 믿을 것인가?" (0 ~ 1 사이 값)
    % R(센서 노이즈)이 크면 K는 작아짐 -> "센서가 시끄러우니 내 예측(모델)을 믿겠다"
    % P(내 불확실성)가 크면 K는 커짐 -> "내가 잘 모르겠으니 센서값을 믿겠다"
    K = P_Pred * H' / (H * P_Pred * H' + R);
    
    % (7) 최종 SOC 보정 (A Posteriori State Estimate)
    % 예측값에 (이득 * 오차)만큼을 더해서 최종 위치를 수정합니다.
    % 센서값과 예측값 사이의 '황금 비율' 지점을 찾아가는 과정입니다.
    EKF_SOC = EKF_SOC_Pred + K * Innovation;
    
    % (8) 오차 공분산 업데이트 (A Posteriori Error Covariance)
    % 센서 데이터로 위치를 보정했으니, 불확실성(P)은 줄어듭니다(1 - KH).
    % 다음 루프에서는 더 자신감 있게 예측을 시작할 수 있습니다.
    P = (1 - K * H) * P_Pred;

end

%% 4. 결과 그래프
figure(2);
subplot(2,1,1);
plot(Time, Current_Meas, 'g', 'LineWidth', 0.5); hold on;
plot(Time, Current_True, 'k', 'LineWidth', 1.5);
title('Current Profile: True vs Measured (Noisy)');
legend('Measured (Sensor Noise)', 'True Current');
ylabel('Current [A]'); grid on;

subplot(2,1,2);
plot(Time, Log_True_SOC, 'k', 'LineWidth', 2); hold on;
plot(Time, Log_Ah_SOC, 'b--', 'LineWidth', 1.0);
plot(Time, Log_EKF_SOC, 'r-.', 'LineWidth', 2.0);
title('SOC Estimation Comparison');
xlabel('Time [sec]'); ylabel('SOC [-]');
legend('True SOC', 'Ampere Counting (Drifting)', 'EKF (Corrected)');
grid on;
