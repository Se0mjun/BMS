%% BMS 기초 시뮬레이션: 전류 적산법(Coulomb Counting)과 등가회로 모델
% 작성일: 2026.01.07
% 설명: 1-RC 모델의 저항 성분만 고려하여 배터리 방전 특성을 시뮬레이션함

clear all; clc; close all; % 작업 공간 초기화 (변수 삭제, 명령창 청소, 그래프 닫기)

%% 1. 파라미터 설정 (Parameter Setting)
Capacity = 2.0;    % 배터리 용량 [Ah] (2A로 1시간 사용 가능)
SOC_init = 1.0;    % 초기 SOC (State of Charge) [1.0 = 100%, 0.0 = 0%]
dt = 1;            % 샘플링 시간 [초] (이 시간이 짧을수록 정밀하지만 계산량 증가)
R0 = 0.05;         % 배터리 내부 저항 [Ohm]
Time = 0:dt:3600;  % 시뮬레이션 시간: 0초부터 3600초까지 1초 간격

% 입력 전류 생성 (방전 시나리오)
% ones(size(Time)): 시간 배열과 똑같은 크기로 1을 꽉 채운 뒤
% 2를 곱해서 '2A 정전류(Constant Current)' 상태를 만듦
Current = 2 * ones(size(Time)); 

%% 2. 메모리 할당 (Memory Allocation) - 속도 최적화 핵심
% 빈 배열([])에 값을 계속 추가하면 매트랩 속도가 매우 느려짐
% 따라서, 미리 0으로 가득 찬 방(zeros)을 만들어 놓고 값을 덮어쓰는 방식을 사용함
SOC = zeros(size(Time)); 
Voltage = zeros(size(Time)); 

%% 3. 초기값 설정 (Initialization)
% for문은 k=2(두 번째)부터 시작하므로, 첫 번째(0초) 값은 미리 넣어줘야 함
SOC(1) = SOC_init;

% t=0 시점의 전압 계산
% V = OCV - IR (방전이므로 전압 강하 발생)
OCV_start = 3.0 + 1.2 * SOC_init;        % 초기 OCV
Voltage(1) = OCV_start - Current(1) * R0; % 초기 단자 전압

%% 4. 루프 시뮬레이션 (Loop Simulation)
% k = 2부터 시작하는 이유:
% 적산법은 '이전 상태(k-1)'를 참고해야 하는데, k=1이면 '0번째'를 찾게 되어 에러 발생함
for k = 2:length(Time)
    
    % (1) SOC 계산: 전류 적산법 (Coulomb Counting)
    % 식: 현재SOC = 이전SOC - (흐른전류 * 시간) / 전체용량
    % *방전이므로 뺍니다 (-). 충전이면 더해야 합니다 (+).
    % *3600을 곱하는 이유: Capacity는 [Ah] 단위이고 dt는 [sec] 단위이므로 단위를 통일하기 위함
    SOC(k) = SOC(k-1) - (Current(k) * dt) / (Capacity * 3600);
    
    % (2) OCV 조회 (Open Circuit Voltage)
    % 가정: OCV는 SOC에 비례하는 1차 함수라고 단순 가정 (실제로는 비선형 Lookup Table 사용)
    OCV = 3.0 + 1.2 * SOC(k);
    
    % (3) 단자 전압(Terminal Voltage) 계산
    % 옴의 법칙: V_term = OCV - I * R (내부저항에 의한 전압 강하 반영)
    % Voltage(k)라고 인덱스를 명시해야 배열의 해당 칸에 값이 저장됨
    Voltage(k) = OCV - Current(k) * R0; 
    
end

%% 5. 결과 그래프 출력 (Plotting)
figure(1); % 그림 창 생성

% 첫 번째 그래프: SOC 변화
subplot(2,1,1);       % 2행 1열 중 1번째 칸
plot(Time, SOC, 'LineWidth', 1.5); % 선 굵기 1.5로 그림
grid on;              % 격자 표시
xlabel('Time [sec]'); % x축 라벨
ylabel('SOC [-]');    % y축 라벨
title('State of Charge (SOC) Change');
ylim([-0.1 1.1]);     % y축 범위 고정 (보기 좋게)

% 두 번째 그래프: 전압 변화
subplot(2,1,2);       % 2행 1열 중 2번째 칸
plot(Time, Voltage, 'r', 'LineWidth', 1.5); % 빨간색('r') 선으로 그림
grid on;
xlabel('Time [sec]');
ylabel('Voltage [V]');
title('Terminal Voltage Profile');
