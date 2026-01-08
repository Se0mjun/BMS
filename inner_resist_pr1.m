%% BMS 심화: RLS(Recursive Least Squares) 기반 내부 저항(SOH) 추정
% 작성일: 2026.01.08
% 설명: 배터리 사용 중 내부 저항이 변할 때, 이를 실시간으로 추적하는 알고리즘
clear all; clc; close all;

%% 1. 파라미터 및 시나리오 설정
dt = 1;                 % 샘플링 시간 (1초마다 측정)
Time = 0:dt:2000;       % 총 2000초 동안 시뮬레이션 진행

% -------------------------------------------------------------------------
% [핵심 질문] 왜 전류를 이렇게 복잡하게(Sin파 + 노이즈) 만들었나요?
% -------------------------------------------------------------------------
% 1. 수학적 이유 (Persistence of Excitation):
%    RLS 알고리즘이 저항(R)을 계산하려면 V = I * R 식에서 I(전류)가 계속 변해야 합니다.
%    만약 전류가 2A로 일정하다면, 수학적으로 이것이 R에 의한 전압강하인지, 
%    OCV 자체가 변한 건지 구분하기가 매우 힘듭니다.
% 2. 물리적 이유:
%    실제 전기차 주행 환경은 가속/감속을 반복하므로 전류가 사인파처럼 출렁이고,
%    도로 노면 진동 등으로 인해 노이즈가 섞입니다. 이를 모사한 것입니다.
% -------------------------------------------------------------------------
Current = 2 * sin(0.01*Time) + 0.5*randn(size(Time)); 

% [시뮬레이션 시나리오 설정]
% "멀쩡하던 배터리가 1000초 시점에 갑자기 늙거나 고장난 상황"을 가정합니다.
% - 0~1000초: 저항 0.05옴 (새 배터리 상태)
% - 1000초~ : 저항 0.08옴 (노화되거나 접촉 불량 발생) -> 알고리즘이 이걸 눈치채야 함!
True_R0 = 0.05 * ones(size(Time)); 
True_R0(1001:end) = 0.08; 

%% 2. 초기화 및 메모리 할당 (Initialization)

% (1) RLS 알고리즘을 위한 초기값 (Start Point)
Theta = 0.01;      % [추정할 파라미터]: 우리는 '저항'을 찾고 싶으므로 일단 0.01옴으로 찍고 시작합니다.
                   % (실제값 0.05와 다르지만, 알고리즘이 알아서 수정해 나갈 겁니다)

P = 100;           % [추정의 불확실성]: 초기값(0.01)에 대한 나의 확신 정도입니다.
                   % 값이 클수록 "나 지금 아무것도 모르니까, 데이터 들어오면 크게크게 수정해라"라는 뜻입니다.

lambda = 0.99;     % [망각 인자 (Forgetting Factor)]: 가장 중요한 튜닝 파라미터! (0.9 ~ 0.999 사용)
                   % 역할: "과거의 데이터를 얼마나 빨리 잊을 것인가?"
                   % - 1.0 : 과거를 절대 잊지 않음 (모든 데이터를 평균냄 -> 저항이 변해도 반응이 느림)
                   % - 0.9 : 과거를 빨리 잊음 (최신 데이터 중시 -> 저항 변화를 빨리 쫓아가지만 값이 엄청 흔들림)
                   % 결론: 0.99는 "적당히 안정적이면서 변화도 감지하겠다"는 세팅입니다.

% (2) 데이터 저장용 빈 방 만들기 (Matlab 속도 최적화)
Log_True_R0 = zeros(size(Time)); % 정답지 기록
Log_Est_R0  = zeros(size(Time)); % 알고리즘이 푼 답 기록
Log_Voltage = zeros(size(Time)); % 전압 데이터 기록

% (3) 배터리 OCV 가정
% RLS는 오직 '저항(R)'만 추정하는 예제이므로, OCV는 3.7V로 고정되었다고 가정합니다.
% (복잡한 예제에서는 EKF로 SOC를 구하고 -> 그 SOC로 OCV를 구해서 넣어줍니다)
OCV_Fixed = 3.7; 

%% 3. 루프 시뮬레이션 (Main Loop)
for k = 1:length(Time)
    
    %% [A] 실제 세상 (Real World Simulation)
    % 실제 저항값(True_R0)을 대입하여 전압을 만들어냅니다.
    % V_meas = OCV - I * R_true + Noise
    % (우리가 계측기로 찍어보는 전압값입니다)
    Voltage_Meas = OCV_Fixed - Current(k) * True_R0(k) + 0.001*randn;
    
    %% [B] RLS 알고리즘 (Recursive Least Squares)
    % "전압(V)과 전류(I) 데이터를 줄 테니, 저항(R)을 찾아내라!"
    
    % [수식 변환 단계]
    % 기본 식: V = OCV - I * R
    % R을 구하기 편하게 이항: (OCV - V) = I * R
    % 이를 RLS 표준형 y = phi * theta 로 매핑합니다.
    %  - y (관측된 결과): 전압 강하량 (OCV - V)
    %  - phi (입력 데이터): 전류 (I)
    %  - theta (찾고 싶은 값): 저항 (R)
    
    y = OCV_Fixed - Voltage_Meas; % y: 전압이 이만큼 떨어졌네?
    phi = Current(k);             % phi: 전류가 이만큼 흘렀으니까..
    
    % 1. 에러 계산 (Prediction Error)
    % "내 지금 저항값(Theta)으로 계산하면 전압강하가 얼마여야 하는데, 실제(y)랑 얼마나 다르지?"
    prediction_error = y - (phi * Theta);
    
    % 2. 이득(Gain, K) 계산
    % "이 에러를 보고 저항값을 얼마나 크게 수정해야 할까?"
    % P(불확실성)가 크거나 phi(입력전류)가 크면 K가 커져서 과감하게 수정합니다.
    K = (P * phi) / (lambda + phi^2 * P);
    
    % 3. 파라미터(저항) 업데이트 (Core Update)
    % "기존 저항값 + (적절한 비율 * 에러)" 형태로 값을 갱신합니다.
    Theta = Theta + K * prediction_error;
    
    % 4. 공분산 행렬(P) 업데이트
    % "한번 학습했으니, 이제 내 추정값에 대해 좀 더 확신을 갖자(불확실성 P 감소)"
    % 동시에 망각인자(lambda)로 나눠주어 P가 0이 되어 학습을 멈추는 것을 방지합니다(지속적 학습).
    P = (1/lambda) * (P - K * phi * P);
    
    %% [C] 데이터 저장
    Log_True_R0(k) = True_R0(k); % 실제 정답
    Log_Est_R0(k)  = Theta;      % 알고리즘의 추정값
    Log_Voltage(k) = Voltage_Meas;
end

%% 4. 결과 그래프 출력
figure(4);

% (1) 입력 전류 그래프
subplot(2,1,1);
plot(Time, Current, 'Color', [0.5 0.5 0.5]); 
title('Input Current Profile (Excitation Signal)');
ylabel('Current [A]'); grid on;
% 설명: 전류가 멈추지 않고 계속 흔들려야 RLS가 저항을 잘 찾습니다.

% (2) 저항 추정 결과 그래프 (하이라이트)
subplot(2,1,2);
plot(Time, Log_True_R0, 'k', 'LineWidth', 2); hold on; % 검은선: 실제 저항 (정답)
plot(Time, Log_Est_R0, 'r--', 'LineWidth', 1.5);      % 빨간점선: RLS 추정값
title('SOH Estimation: Internal Resistance Tracking');
ylabel('Resistance [Ohm]'); xlabel('Time [sec]');
legend('True R (Step Change)', 'Estimated R (RLS)');
grid on;
ylim([0 0.1]); % y축 범위 고정 (보기 좋게)

% [그래프 해석 포인트]
% 1. 0초 근처: 빨간 선이 0.01에서 시작해서 순식간에 0.05로 올라붙습니다 (초기 수렴).
% 2. 1000초 지점: 검은 선이 0.08로 팍 튀었을 때, 빨간 선이 얼마나 빨리 따라가는지 보세요.
% 3. 만약 lambda를 0.99 -> 0.999로 바꾸면? -> 따라가는 속도가 느려집니다.
% 4. 만약 lambda를 0.99 -> 0.90으로 바꾸면? -> 속도는 빠르지만 빨간 선이 엄청 덜덜거립니다(노이즈 민감).
