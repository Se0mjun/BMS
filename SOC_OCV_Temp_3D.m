%% 1. 실험 데이터 정의 (현업 데이터 시트 기반 가상 데이터)
% SOC 좌표 (0% ~ 100%)
SOC_basis = [0, 5, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]; 

% 온도 좌표 (Celsius)
Temp_basis = [-20, -10, 0, 10, 25, 45]; 

% OCV 데이터 매트릭스 (Row: SOC, Column: Temperature)
% 실제 배터리는 저온에서 내부 화학 반응이 느려져 전압 강하가 더 심하게 나타납니다.
OCV_data = [
    3.10, 3.15, 3.20, 3.25, 3.30, 3.32; % SOC 0%
    3.35, 3.40, 3.45, 3.48, 3.50, 3.52; % SOC 5%
    3.50, 3.55, 3.58, 3.60, 3.62, 3.63; % SOC 10%
    3.62, 3.65, 3.68, 3.70, 3.72, 3.73; % SOC 20%
    3.70, 3.73, 3.75, 3.77, 3.78, 3.79; % SOC 30%
    3.78, 3.80, 3.82, 3.83, 3.84, 3.85; % SOC 40%
    3.85, 3.87, 3.89, 3.90, 3.91, 3.92; % SOC 50%
    3.92, 3.94, 3.95, 3.96, 3.97, 3.98; % SOC 60%
    3.98, 4.00, 4.01, 4.02, 4.03, 4.04; % SOC 70%
    4.05, 4.06, 4.07, 4.08, 4.09, 4.10; % SOC 80%
    4.12, 4.13, 4.14, 4.15, 4.16, 4.17; % SOC 90%
    4.18, 4.19, 4.20, 4.21, 4.22, 4.23  % SOC 100%
];

%% 2. 그리드 생성 및 보간 (Interpolation)
% 실험 데이터보다 더 촘촘한 해상도로 맵을 확장합니다.
[T_grid, S_grid] = meshgrid(linspace(min(Temp_basis), max(Temp_basis), 50), ...
                            linspace(min(SOC_basis), max(SOC_basis), 50));

% interp2 함수를 사용하여 매끄러운 3D 곡면 데이터 생성
OCV_interp = interp2(Temp_basis, SOC_basis, OCV_data, T_grid, S_grid, 'linear');

%% 3. 3차원 시각화
figure('Color', 'w');
surf(T_grid, S_grid, OCV_interp, 'EdgeColor', 'none'); % 매끄러운 곡면
hold on;
mesh(T_grid, S_grid, OCV_interp, 'FaceAlpha', 0); % 격자선 추가
scatter3(reshape(repmat(Temp_basis, length(SOC_basis), 1), [], 1), ...
         reshape(repmat(SOC_basis', 1, length(Temp_basis)), [], 1), ...
         OCV_data(:), 'filled', 'MarkerFaceColor', 'r'); % 원본 실험 데이터 포인터 점

% 그래프 꾸미기
xlabel('Temperature (^\circ C)');
ylabel('SOC (%)');
zlabel('Open Circuit Voltage (V)');
title('Battery SOC-OCV-Temp Lookup Table (BMS Model)');
colorbar;
view(-45, 30); % 보기 각도 조절
grid on;
