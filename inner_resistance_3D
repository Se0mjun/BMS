%% 1. 내부 저항 실험 데이터 정의
SOC_range = [0, 10, 20, 50, 80, 100];      % %
Temp_range = [-20, -10, 0, 25, 45];        % Celsius

% 내부 저항 데이터 (mOhm 단위)
% 저온/저SOC일수록 저항이 급격히 커지는 특성을 반영
Resistance_data = [
    150, 100, 80, 50, 40;  % SOC 0% (온도별 저항)
    100,  70, 55, 35, 30;  % SOC 10%
    80,   55, 40, 25, 22;  % SOC 20%
    50,   35, 25, 18, 15;  % SOC 50%
    45,   32, 22, 16, 14;  % SOC 80%
    45,   32, 22, 16, 14   % SOC 100%
];

%% 2. 3D 저항 맵 생성 (보간법 적용)
[T_grid, S_grid] = meshgrid(linspace(-20, 45, 50), linspace(0, 100, 50));
R_map = interp2(Temp_range, SOC_range, Resistance_data, T_grid, S_grid, 'spline');

%% 3. 실시간 Derating 시나리오 시뮬레이션
curr_temp = -10;  % 현재 온도
curr_soc = 20;    % 현재 SOC

% 현재 상태에서의 저항값 추출
curr_R = interp2(Temp_range, SOC_range, Resistance_data, curr_temp, curr_soc, 'linear');

% Derating 로직 (간단한 예시)
% 저항이 50mOhm 이상이면 전류를 비례해서 줄임
max_current_ref = 100; % 정상 상태 최대 전류 (A)
if curr_R > 30
    derating_factor = 30 / curr_R; % 저항이 클수록 인자가 작아짐
else
    derating_factor = 1.0;
end
limit_current = max_current_ref * derating_factor;

fprintf('현재 상태: 온도 %.1fC, SOC %.1f%%\n', curr_temp, curr_soc);
fprintf('추정 내부 저항: %.2f mOhm\n', curr_R);
fprintf('제한된 허용 전류: %.2f A (정상 대비 %.1f%%)\n', limit_current, derating_factor*100);

%% 4. 시각화
figure('Color', 'w');
surf(T_grid, S_grid, R_map);
hold on;
% 현재 배터리 상태를 맵 위에 표시
plot3(curr_temp, curr_soc, curr_R, 'ro', 'MarkerSize', 15, 'LineWidth', 3);
text(curr_temp, curr_soc, curr_R+10, ' Current State', 'FontSize', 12, 'FontWeight', 'bold');

xlabel('Temperature (^\circ C)'); ylabel('SOC (%)'); zlabel('Resistance (m\Omega)');
title('Battery Internal Resistance Map & Derating Point');
colorbar; view(-135, 30);
