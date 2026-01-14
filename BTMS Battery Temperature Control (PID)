%% 1. 파라미터 설정
dt = 0.1;               % 시뮬레이션 타임스텝 (s)
total_time = 500;       % 전체 시뮬레이션 시간 (s)
t = 0:dt:total_time;

% 배터리 물리적 특성
current = 50;           % 방전 전류 (A)
heat_capacity = 1000;   % 배터리 열용량 (J/K)
ambient_temp = 20;      % 주변 온도 (C)
target_temp = 25;       % 목표 유지 온도 (C)

% 초기 상태
battery_temp = zeros(size(t));
battery_temp(1) = ambient_temp;

% PID 제어기 게인 (튜닝 필요)
Kp = 15; Ki = 0.5; Kd = 2;
error_sum = 0; prev_error = 0;

%% 2. 시뮬레이션 루프
for i = 1:length(t)-1
    % A. 현재 온도에 따른 내부 저항 계산 (앞서 만든 3D 맵 로직 연동 가능)
    % 여기서는 단순화하여 온도가 오를수록 저항이 줄어드는 선형 모델 적용
    R_internal = 0.05 * (1 - 0.01 * (battery_temp(i) - 20)); 
    
    % B. 발열량 계산 (Q = I^2 * R)
    Q_heat = (current^2) * R_internal;
    
    % C. PID 제어 (냉각 팬 출력 계산)
    error = battery_temp(i) - target_temp;
    error_sum = error_sum + error * dt;
    error_diff = (error - prev_error) / dt;
    
    fan_output = Kp*error + Ki*error_sum + Kd*error_diff;
    fan_output = max(0, min(fan_output, 1000)); % 팬 출력 제한 (0~1000W)
    
    % D. 온도 변화 계산 (발열 - 냉각)
    % dT/dt = (Q_heat - Q_cooling) / Heat_Capacity
    dT = (Q_heat - fan_output) / heat_capacity;
    battery_temp(i+1) = battery_temp(i) + dT * dt;
    
    prev_error = error;
end

%% 3. 결과 시각화
figure('Color', 'w');
subplot(2,1,1);
plot(t, battery_temp, 'LineWidth', 2); hold on;
yline(target_temp, 'r--', 'Target Temp');
grid on; ylabel('Temperature (^\circ C)');
title('BTMS: Battery Temperature Control (PID)');

subplot(2,1,2);
plot(t, ones(size(t))*current, 'g', 'LineWidth', 2);
grid on; ylabel('Current (A)'); xlabel('Time (s)');
title('Discharge Current Profile');
