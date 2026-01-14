%% 1. 파라미터 설정
dt = 0.1;               % 시뮬레이션 타임스텝 (s)
t = 0:dt:1000;          % 전체 시뮬레이션 시간 (1000초)

% 배터리 등가회로 파라미터 (가상값)
Q_cap = 3000 * 3600;    % 배터리 용량 (As, 3000mAh)
R0 = 0.05;              % 직렬 저항 (Ohm)
R1 = 0.03;              % 분극 저항 (Ohm)
C1 = 2000;              % 분극 커패시턴스 (Farad)
tau = R1 * C1;          % 시각상수 (Time Constant)

% 초기 상태
soc = 0.8;              % 초기 SOC (80%)
v_r1 = 0;               % 초기 RC 전압
vt_history = zeros(size(t));
soc_history = zeros(size(t));

%% 2. 전류 프로필 생성 (펄스 방전)
% 100초~400초 사이만 20A 방전, 그 외에는 0A (휴지기)
current_profile = zeros(size(t));
current_profile(t > 100 & t < 400) = 20; 

%% 3. 시뮬레이션 루프
for i = 1:length(t)
    I = current_profile(i);
    
    % A. OCV 계산 (단순화를 위해 선형 모델 사용, 3D 맵 연동 가능)
    Voc = 3.4 + 0.8 * soc;
    
    % B. RC 전압 업데이트 (이산 시간 근사)
    v_r1 = v_r1 * exp(-dt/tau) + R1 * I * (1 - exp(-dt/tau));
    
    % C. 단자 전압(Vt) 계산
    vt = Voc - I * R0 - v_r1;
    
    % D. SOC 업데이트
    soc = soc - (I * dt) / Q_cap;
    
    % 결과 저장
    vt_history(i) = vt;
    soc_history(i) = soc;
end

%% 4. 결과 시각화
figure('Color', 'w', 'Position', [100 100 800 600]);

subplot(3,1,1);
plot(t, current_profile, 'r', 'LineWidth', 1.5);
ylabel('Current (A)'); grid on; title('Pulse Discharge Current');

subplot(3,1,2);
plot(t, vt_history, 'b', 'LineWidth', 1.5);
ylabel('Terminal Voltage (V)'); grid on; title('Battery Terminal Voltage (Thevenin Model)');
hold on; 
% 전압 회복 구간 강조
text(450, vt_history(450)+0.05, '\leftarrow Voltage Relaxation', 'Color', 'k', 'FontWeight', 'bold');

subplot(3,1,3);
plot(t, soc_history * 100, 'g', 'LineWidth', 1.5);
ylabel('SOC (%)'); xlabel('Time (s)'); grid on; title('State of Charge');
