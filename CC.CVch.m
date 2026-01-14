%% 1. 배터리 및 제어 파라미터 설정
dt = 1;                     % 초 단위 시뮬레이션
t_end = 7200;               % 최대 2시간 시뮬레이션
t = 0:dt:t_end;

% 테브난 모델 파라미터
V_max = 4.2;                % 최대 충전 전압 (V)
I_cutoff = 0.1;             % 충전 종료 전류 (A)
I_cc = 2.0;                 % CC 단계 충전 전류 (A, 1C 가정)
Q_cap = 2 * 3600;           % 용량 (2Ah -> As 단위)
R0 = 0.05; R1 = 0.03; C1 = 1500;

% 초기 상태
soc = 0.1;                  % 10%에서 시작
v_r1 = 0;
I_sim = zeros(size(t));
V_sim = zeros(size(t));
soc_sim = zeros(size(t));
mode = "CC";                % 초기 모드 설정

%% 2. CC-CV 제어 루프
for i = 1:length(t)
    % A. 현재 SOC에 따른 Voc 계산
    Voc = 3.4 + 0.8 * soc;
    
    % B. 충전 제어 로직
    if mode == "CC"
        I = I_cc;
        % 전압 예측 (V = Voc + I*R0 + V_r1)
        V_predict = Voc + I * R0 + v_r1;
        if V_predict >= V_max
            mode = "CV";
        end
    elseif mode == "CV"
        % 전압을 V_max로 고정하기 위한 전류 계산 (V_max = Voc + I*R0 + V_r1)
        I = (V_max - Voc - v_r1) / R0;
        if I < I_cutoff
            I = 0; % 충전 완료
        end
    end
    
    % C. 모델 업데이트
    v_r1 = v_r1 * exp(-dt/(R1*C1)) + R1 * I * (1 - exp(-dt/(R1*C1)));
    soc = soc + (I * dt) / Q_cap;
    
    % 데이터 기록
    I_sim(i) = I;
    V_sim(i) = Voc + I * R0 + v_r1;
    soc_sim(i) = soc;
end

%% 3. 결과 시각화
figure('Color', 'w');
subplot(3,1,1); plot(t/60, V_sim, 'b', 'LineWidth', 2); grid on;
ylabel('Voltage (V)'); title('CC-CV Charging: Voltage');
subplot(3,1,2); plot(t/60, I_sim, 'r', 'LineWidth', 2); grid on;
ylabel('Current (A)'); title('CC-CV Charging: Current');
subplot(3,1,3); plot(t/60, soc_sim*100, 'g', 'LineWidth', 2); grid on;
ylabel('SOC (%)'); xlabel('Time (min)'); title('SOC Growth');
