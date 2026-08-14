function PacMan()
clc;
close all;

%% =========================================================
%                         PAC-MAN
%                    MATLAB 经典复现
%
%  ↑ ↓ ← → / WASD   移动
%  P                暂停
%  SPACE            重新开始
%  ESC              退出
%
%  音效：
%  pacman_bgm.mp3   背景音乐
%  其它音效均由 MATLAB 实时合成
%
% ==========================================================


%% =========================================================
%                         基本参数
% ==========================================================

ROWS = 31;
COLS = 28;
TILE = 22;

START_LIVES = 3;

PLAYER_STEP_TIME = 0.155;
GHOST_STEP_TIME  = 0.155;

SPEED_INCREASE = 0.004;


%% =========================================================
%                           地图
% ==========================================================

mazeText = {
'############################'
'#............##............#'
'#.####.#####.##.#####.####.#'
'#o####.#####.##.#####.####o#'
'#.####.#####.##.#####.####.#'
'#..........................#'
'#.####.##.########.##.####.#'
'#.####.##.########.##.####.#'
'#......##....##....##......#'
'######.##### ## #####.######'
'######.##### ## #####.######'
'######.##          ##.######'
'######.## ###  ### ##.######'
'######.## #      # ##.######'
'      .   #      #   .      '
'######.## #      # ##.######'
'######.## ######## ##.######'
'######.##          ##.######'
'######.## ######## ##.######'
'######.## ######## ##.######'
'#............##............#'
'#.####.#####.##.#####.####.#'
'#.####.#####.##.#####.####.#'
'#o..##.......  .......##..o#'
'###.##.##.########.##.##.###'
'###.##.##.########.##.##.###'
'#......##....##....##......#'
'#.##########.##.##########.#'
'#.##########.##.##########.#'
'#..........................#'
'############################'
};

maze = char(mazeText);

if size(maze,1) ~= ROWS || size(maze,2) ~= COLS
    error('地图尺寸不是 31 × 28，请检查 mazeText。');
end


%% =========================================================
%                         豆子
% ==========================================================

pellets = maze == '.';
powerPellets = maze == 'o';


%% =========================================================
%                         游戏状态
% ==========================================================

score = 0;
lives = START_LIVES;
level = 1;

extraLifeGiven = false;

state = 'ready';

readyTimer = tic;
deathTimer = [];
levelClearTimer = [];


%% =========================================================
%                           玩家
% ==========================================================

playerPos = [24 15];

playerDir = [0 -1];
wantedDir = [0 -1];

playerMoveClock = tic;


%% =========================================================
%                            鬼
% ==========================================================

ghostNames = {
    'Blinky'
    'Pinky'
    'Inky'
    'Clyde'
};

ghostColors = [
    1.00 0.05 0.05
    1.00 0.45 0.75
    0.15 0.85 1.00
    1.00 0.60 0.10
];

ghostPos = [
    12 14
    15 12
    15 14
    15 16
];

ghostDir = [
     0 -1
    -1  0
    -1  0
     1  0
];

ghostActive = [
    true
    false
    false
    false
];

ghostEaten = false(4,1);

% 鬼屋出生点
ghostHome = [15 14];


%% =========================================================
%                       鬼释放计时器
% ==========================================================

ghostReleaseTime = [
    0
    1.8
    3.6
    5.4
];

ghostReleaseClock = tic;


%% =========================================================
%                    Scatter / Chase
% ==========================================================

mode = 'scatter';

modeIndex = 1;

modeTimes = [
     7
    20
     7
    20
     5
    20
     5
    inf
];

modeClock = tic;


%% =========================================================
%                       Frightened
% ==========================================================

frightened = false;

frightenedTimer = [];

frightenedDuration = 0;

ghostEatCount = 0;


%% =========================================================
%                         动画
% ==========================================================

mouthPhase = 0;


%% =========================================================
%                         音效系统
% ==========================================================

audioFS = 44100;

soundPlayers = {};

% 当前 BGM 播放器
bgmPlayer = [];

% BGM 是否应该循环
bgmShouldLoop = false;

% 是否启用声音
audioEnabled = true;

% 吃豆音效交替
pelletSoundToggle = false;


%% =========================================================
%                     生成所有音效
% ==========================================================

soundData = createSoundEffects(audioFS);


%% =========================================================
%                       加载背景音乐
% ==========================================================

bgmFile = fullfile(fileparts(mfilename('fullpath')),'pacman_bgm.mp3');

if exist(bgmFile,'file')

    try

        [bgmData,bgmFs] = audioread(bgmFile);

        % 如果是双声道，保留原始双声道
        bgmPlayer = audioplayer(bgmData,bgmFs);

        bgmPlayer.StopFcn = @bgmLoop;

    catch ME

    warning('PacManpro:AudioLoadFailed', ...
        '背景音乐加载失败：%s', ...
        ME.message);

        bgmPlayer = [];

    end

else

    warning( ...
        '没有找到 pacman_bgm.mp3。请将它放到 PacManpro.m 同一文件夹。');

end


%% =========================================================
%                           GUI
% ==========================================================

fig = figure( ...
    'Name','PAC-MAN - MATLAB', ...
    'NumberTitle','off', ...
    'Color',[0 0 0], ...
    'MenuBar','none', ...
    'ToolBar','none', ...
    'Resize','off', ...
    'Position',[250 50 COLS*TILE+80 ROWS*TILE+120], ...
    'KeyPressFcn',@keyDown, ...
    'CloseRequestFcn',@closeGame);


%% =========================================================
%                          坐标轴
% ==========================================================

ax = axes( ...
    'Parent',fig, ...
    'Position',[0.035 0.08 0.93 0.86], ...
    'Color',[0 0 0]);

hold(ax,'on');

axis(ax,'equal');

xlim(ax,[0.5 COLS+0.5]);

ylim(ax,[0.5 ROWS+1.8]);

set(ax,'YDir','reverse');

ax.XTick = [];
ax.YTick = [];
ax.Box = 'off';


%% =========================================================
%                         绘制迷宫
% ==========================================================

drawMaze();


%% =========================================================
%                           豆子
% ==========================================================

[r,c] = find(pellets);

pelletHandle = scatter( ...
    ax,c,r,13,'filled', ...
    'MarkerFaceColor',[1 1 1], ...
    'MarkerEdgeColor','none');


[r,c] = find(powerPellets);

powerHandle = scatter( ...
    ax,c,r,65,'filled', ...
    'MarkerFaceColor',[1 1 1], ...
    'MarkerEdgeColor','none');


%% =========================================================
%                         Pac-Man
% ==========================================================

[px,py] = pacmanShape( ...
    playerPos, ...
    playerDir, ...
    true);

playerHandle = patch( ...
    ax, ...
    px,py, ...
    [1 1 0], ...
    'EdgeColor','none');


%% =========================================================
%                           四只鬼
% ==========================================================

ghostBody = gobjects(4,1);
ghostEyeWhite = gobjects(4,1);
ghostPupil = gobjects(4,1);

for g = 1:4

    [gx,gy] = ghostShape(ghostPos(g,:));

    ghostBody(g) = patch( ...
        ax, ...
        gx,gy, ...
        ghostColors(g,:), ...
        'EdgeColor','none');


    t = linspace(0,2*pi,20);

    ex1 = ghostPos(g,2)-0.15 + 0.11*cos(t);
    ey1 = ghostPos(g,1)-0.10 + 0.11*sin(t);

    ex2 = ghostPos(g,2)+0.15 + 0.11*cos(t);
    ey2 = ghostPos(g,1)-0.10 + 0.11*sin(t);

    ghostEyeWhite(g) = patch( ...
        ax, ...
        [ex1 ex2], ...
        [ey1 ey2], ...
        [1 1 1], ...
        'EdgeColor','none');


    px1 = ghostPos(g,2)-0.15 + 0.055*cos(t);
    py1 = ghostPos(g,1)-0.10 + 0.055*sin(t);

    px2 = ghostPos(g,2)+0.15 + 0.055*cos(t);
    py2 = ghostPos(g,1)-0.10 + 0.055*sin(t);

    ghostPupil(g) = patch( ...
        ax, ...
        [px1 px2], ...
        [py1 py2], ...
        [0.05 0.10 0.80], ...
        'EdgeColor','none');

end


%% =========================================================
%                            HUD
% ==========================================================

scoreText = text( ...
    ax, ...
    1,32.25, ...
    sprintf('SCORE  %06d',score), ...
    'Color','white', ...
    'FontSize',12, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left');


levelText = text( ...
    ax, ...
    COLS/2,32.25, ...
    sprintf('LEVEL %d',level), ...
    'Color','white', ...
    'FontSize',12, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','center');


livesText = text( ...
    ax, ...
    COLS,32.25, ...
    makeHearts(lives), ...
    'Color',[1 0.15 0.20], ...
    'FontSize',14, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','right');


%% =========================================================
%                         中央提示
% ==========================================================

messageText = text( ...
    ax, ...
    COLS/2,21, ...
    'READY!', ...
    'Color',[1 1 0], ...
    'FontSize',16, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','center');


%% =========================================================
%                    Frightened 倒计时
% ==========================================================

frightenedText = text( ...
    ax, ...
    COLS/2,20, ...
    '', ...
    'Color',[0.2 0.6 1], ...
    'FontSize',10, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','center');


%% =========================================================
%                  初始化计时器
% ==========================================================

playerMoveClock = tic;
ghostMoveClock = tic;


%% =========================================================
%                        游戏 Timer
% ==========================================================

gameTimer = timer( ...
    'ExecutionMode','fixedSpacing', ...
    'Period',0.03, ...
    'BusyMode','drop', ...
    'TimerFcn',@gameTick);


start(gameTimer);

drawGame();


%% =========================================================
%                         播放 READY 音效
% ==========================================================

playEffect('ready');


%% =========================================================
%                         键盘控制
% ==========================================================

function keyDown(~,event)

    key = lower(event.Key);

    switch key

        case {'uparrow','w'}

            wantedDir = [-1 0];

        case {'downarrow','s'}

            wantedDir = [1 0];

        case {'leftarrow','a'}

            wantedDir = [0 -1];

        case {'rightarrow','d'}

            wantedDir = [0 1];

        case 'p'

            if strcmp(state,'playing')

                state = 'paused';

                messageText.String = 'PAUSED';

                pauseBGM();

            elseif strcmp(state,'paused')

                state = 'playing';

                messageText.String = '';

                playerMoveClock = tic;
                ghostMoveClock = tic;

                resumeBGM();

            end

        case 'space'

            resetWholeGame();

        case 'escape'

            closeGame();

    end

end


%% =========================================================
%                        游戏主循环
% =========================================================

function gameTick(~,~)

    if ~isvalid(fig)
        return;
    end


    %% READY

    if strcmp(state,'ready')

        if toc(readyTimer) >= 1.2

            state = 'playing';

            messageText.String = '';

            playerMoveClock = tic;
            ghostMoveClock = tic;

            modeClock = tic;
            ghostReleaseClock = tic;

            startBGM();

        end

        drawGame();

        return;

    end


    %% PAUSED

    if strcmp(state,'paused')

        drawGame();

        return;

    end


    %% GAME OVER

    if strcmp(state,'gameover')

        drawGame();

        return;

    end


    %% LEVEL CLEAR

    if strcmp(state,'levelclear')

        if toc(levelClearTimer) >= 1.5

            nextLevel();

        end

        drawGame();

        return;

    end


    %% DEAD

    if strcmp(state,'dead')

        if toc(deathTimer) >= 1.2

            if lives <= 0

                state = 'gameover';

                messageText.String = ...
                    'GAME OVER - PRESS SPACE';

                stopBGM();

            else

                resetPositions();

                state = 'ready';

                readyTimer = tic;

                messageText.String = 'READY!';

                playEffect('ready');

            end

        end

        drawGame();

        return;

    end


    %% =====================================================
    %                       正常游戏
    % =====================================================

    if strcmp(state,'playing')

        updateFrightened();

        updateMode();

        updateGhostRelease();


        %% 玩家

        playerInterval = ...
            max(0.085, ...
            PLAYER_STEP_TIME - ...
            SPEED_INCREASE*(level-1));


        if toc(playerMoveClock) >= playerInterval

            updatePlayer();

            playerMoveClock = tic;

        end


        %% 鬼

        ghostInterval = ...
            max(0.095, ...
            GHOST_STEP_TIME - ...
            SPEED_INCREASE*(level-1));


        if toc(ghostMoveClock) >= ghostInterval

            updateGhosts();

            ghostMoveClock = tic;

        end


        %% 碰撞

        checkGhostCollision();


        %% 过关

        checkLevelClear();


        mouthPhase = mouthPhase + 1;

    end


    drawGame();

end


%% =========================================================
%                     鬼释放机制
% =========================================================

function updateGhostRelease()

    elapsed = toc(ghostReleaseClock);

    for g = 2:4

        if ~ghostActive(g)

            if elapsed >= ghostReleaseTime(g)

                ghostActive(g) = true;

                ghostDir(g,:) = [-1 0];

            end

        end

    end

end


%% =========================================================
%                         玩家移动
% =========================================================

function updatePlayer()

    if canPlayerMove(playerPos,wantedDir)

        playerDir = wantedDir;

    end


    if ~canPlayerMove(playerPos,playerDir)

        return;

    end


    playerPos = wrapPosition( ...
        playerPos + playerDir);


    r = playerPos(1);
    c = playerPos(2);


    %% 普通豆

    if pellets(r,c)

        pellets(r,c) = false;

        score = score + 10;

        % 经典吃豆音效交替
        pelletSoundToggle = ~pelletSoundToggle;

        if pelletSoundToggle
            playEffect('pellet1');
        else
            playEffect('pellet2');
        end

    end


    %% Power Pellet

    if powerPellets(r,c)

        powerPellets(r,c) = false;

        score = score + 50;

        activateFrightened();

        playEffect('power');

    end


    %% 额外生命

    if score >= 10000 && ~extraLifeGiven

        lives = lives + 1;

        extraLifeGiven = true;

        playEffect('extraLife');

    end

end


%% =========================================================
%                         鬼移动
% =========================================================

function updateGhosts()

    for g = 1:4

        if ~ghostActive(g)
            continue;
        end


        %% =================================================
        %                 被吃掉的鬼
        % ==================================================

        if ghostEaten(g)

            moveGhostHome(g);

            continue;

        end


        %% =================================================
        %                     正常鬼
        % ==================================================

        if frightened

            chooseFrightenedDirection(g);

        else

            chooseTargetDirection(g);

        end


        if canGhostMove( ...
                ghostPos(g,:), ...
                ghostDir(g,:))

            ghostPos(g,:) = ...
                wrapPosition( ...
                ghostPos(g,:) + ghostDir(g,:));

        end

    end

end


%% =========================================================
%                     正常追踪方向
% =========================================================

function chooseTargetDirection(g)

    current = ghostPos(g,:);


    dirs = [
        -1  0
         0 -1
         1  0
         0  1
    ];


    valid = [];


    for k = 1:4

        d = dirs(k,:);


        if isequal(d,-ghostDir(g,:))
            continue;
        end


        if canGhostMove(current,d)

            valid = [valid;d]; %#ok<AGROW>

        end

    end


    if isempty(valid)

        d = -ghostDir(g,:);

        if canGhostMove(current,d)

            ghostDir(g,:) = d;

        end

        return;

    end


    %% =====================================================
    %                    鬼屋出口
    % =====================================================

    if current(1) >= 12 && ...
       current(1) <= 17 && ...
       current(2) >= 11 && ...
       current(2) <= 18

        exitTarget = [14 14];

        bestDist = inf;

        bestDir = valid(1,:);


        for k = 1:size(valid,1)

            d = valid(k,:);

            next = wrapPosition(current+d);


            dist = ...
                abs(next(1)-exitTarget(1)) + ...
                abs(next(2)-exitTarget(2));


            if dist < bestDist

                bestDist = dist;

                bestDir = d;

            end

        end


        ghostDir(g,:) = bestDir;

        return;

    end


    %% =====================================================
    %                     Scatter / Chase
    % =====================================================

    if strcmp(mode,'scatter')

        target = scatterTarget(g);

    else

        target = ghostTarget(g);

    end


    bestDist = inf;

    bestDir = valid(1,:);


    for k = 1:size(valid,1)

        d = valid(k,:);

        next = wrapPosition(current+d);


        dx = abs(next(2)-target(2));

        dx = min(dx,COLS-dx);


        dy = abs(next(1)-target(1));


        dist = dx^2 + dy^2;


        if dist < bestDist

            bestDist = dist;

            bestDir = d;

        end

    end


    ghostDir(g,:) = bestDir;

end


%% =========================================================
%                       四鬼追踪目标
% =========================================================

function target = ghostTarget(g)

    p = playerPos;
    d = playerDir;


    switch g

        case 1

            target = p;


        case 2

            target = p + 4*d;


            if isequal(d,[-1 0])

                target = p + [-4 -4];

            end


        case 3

            ahead = p + 2*d;


            if isequal(d,[-1 0])

                ahead = p + [-2 -2];

            end


            blinky = ghostPos(1,:);

            target = ahead + ...
                (ahead-blinky);


        case 4

            dr = ghostPos(4,1)-p(1);

            dc = ghostPos(4,2)-p(2);

            dist2 = dr^2 + dc^2;


            if dist2 >= 64

                target = p;

            else

                target = [30 2];

            end

    end


    target(1) = max(1,min(ROWS,target(1)));

    target(2) = max(1,min(COLS,target(2)));

end


%% =========================================================
%                         Scatter目标
% ==========================================================

function target = scatterTarget(g)

    switch g

        case 1
            target = [2 27];

        case 2
            target = [2 2];

        case 3
            target = [30 27];

        case 4
            target = [30 2];

    end

end


%% =========================================================
%                      Frightened方向
% ==========================================================

function chooseFrightenedDirection(g)

    current = ghostPos(g,:);


    dirs = [
        -1  0
         0 -1
         1  0
         0  1
    ];


    valid = [];


    for k = 1:4

        d = dirs(k,:);


        if isequal(d,-ghostDir(g,:))
            continue;
        end


        if canGhostMove(current,d)

            valid = [valid;d]; %#ok<AGROW>

        end

    end


    if isempty(valid)

        d = -ghostDir(g,:);

        if canGhostMove(current,d)

            ghostDir(g,:) = d;

        end

        return;

    end


    ghostDir(g,:) = ...
        valid(randi(size(valid,1)),:);

end


%% =========================================================
%                       激活 Frightened
% =========================================================

function activateFrightened()

    duration = getFrightenedDuration(level);


    if duration <= 0
        return;
    end


    frightened = true;

    frightenedTimer = tic;

    frightenedDuration = duration;

    ghostEatCount = 0;


    % 只有没有被吃掉的鬼才反向
    for g = 1:4

        if ghostActive(g) && ~ghostEaten(g)

            ghostDir(g,:) = -ghostDir(g,:);

        end

    end

end


%% =========================================================
%                    Frightened 持续时间
% =========================================================

function t = getFrightenedDuration(lv)

    durationTable = [
        6
        5
        4
        3
        2
        5
        2
        2
        1
        5
        2
        1
        1
        3
        1
        1
    ];


    if lv <= numel(durationTable)

        t = durationTable(lv);

    else

        t = 0;

    end

end


%% =========================================================
%                     Frightened 更新
% =========================================================

function updateFrightened()

    if ~frightened

        frightenedText.String = '';

        return;

    end


    remaining = ...
        frightenedDuration - ...
        toc(frightenedTimer);


    if remaining <= 0

        frightened = false;

        frightenedTimer = [];

        frightenedDuration = 0;

        frightenedText.String = '';


        % Frightened结束：
        % 被吃掉的鬼不能反向
        for g = 1:4

            if ghostActive(g) && ~ghostEaten(g)

                ghostDir(g,:) = -ghostDir(g,:);

            end

        end

        return;

    end


    frightenedText.String = ...
        sprintf('FRIGHTENED  %.1f',remaining);


    if remaining <= 2

        if mod(floor(toc(frightenedTimer)*8),2)

            frightenedText.Color = [1 1 1];

        else

            frightenedText.Color = [0.2 0.6 1];

        end

    else

        frightenedText.Color = [0.2 0.6 1];

    end

end


%% =========================================================
%                     Scatter / Chase
% =========================================================

function updateMode()

    if frightened
        return;
    end


    if modeIndex > numel(modeTimes)
        return;
    end


    if toc(modeClock) >= modeTimes(modeIndex)

        modeIndex = modeIndex + 1;


        if modeIndex > numel(modeTimes)

            modeIndex = numel(modeTimes);

        end


        if mod(modeIndex,2) == 1

            mode = 'scatter';

        else

            mode = 'chase';

        end


        % 只反向正常鬼
        for g = 1:4

            if ghostActive(g) && ~ghostEaten(g)

                ghostDir(g,:) = -ghostDir(g,:);

            end

        end


        modeClock = tic;

    end

end


%% =========================================================
%                    被吃鬼 BFS 回家
% =========================================================

function moveGhostHome(g)

    current = ghostPos(g,:);
    target = ghostHome;


    %% -----------------------------------------------------
    %                 已经回到出生点
    % ------------------------------------------------------

    if isequal(current,target)

        % 鬼复活
        ghostEaten(g) = false;

        % 保证继续参与游戏
        ghostActive(g) = true;

        % 从鬼屋出口向上
        ghostDir(g,:) = [-1 0];

        return;

    end


    %% -----------------------------------------------------
    %                    BFS 寻路
    % ------------------------------------------------------

    nextStep = findNextStepBFS(current,target);


    %% -----------------------------------------------------
    %                  找到有效路径
    % ------------------------------------------------------

    if ~isempty(nextStep)

        d = nextStep - current;

        ghostDir(g,:) = d;

        ghostPos(g,:) = ...
            wrapPosition(nextStep);

    else

        % 理论上不应该发生。
        % 如果发生，则允许掉头寻找出口。

        d = -ghostDir(g,:);

        if canGhostMove(current,d)

            ghostDir(g,:) = d;

            ghostPos(g,:) = ...
                wrapPosition(current+d);

        end

    end

end


%% =========================================================
%                       BFS最短路径
% =========================================================

function nextStep = findNextStepBFS(startPos,targetPos)

    nextStep = [];


    if isequal(startPos,targetPos)

        nextStep = startPos;

        return;

    end


    %% visited

    visited = false(ROWS,COLS);


    %% parent

    parentR = zeros(ROWS,COLS);

    parentC = zeros(ROWS,COLS);


    %% BFS队列

    queue = zeros(ROWS*COLS,2);

    head = 1;
    tail = 1;


    queue(tail,:) = startPos;

    visited(startPos(1),startPos(2)) = true;


    dirs = [
        -1  0
         0 -1
         1  0
         0  1
    ];


    found = false;


    %% =====================================================
    %                       BFS
    % =====================================================

    while head <= tail

        current = queue(head,:);

        head = head + 1;


        if isequal(current,targetPos)

            found = true;

            break;

        end


        for k = 1:4

            d = dirs(k,:);

            next = current + d;


            %% 隧道

            if next(1) == 15

                if next(2) < 1

                    next(2) = COLS;

                elseif next(2) > COLS

                    next(2) = 1;

                end

            end


            r = next(1);
            c = next(2);


            %% 边界

            if r < 1 || r > ROWS || ...
               c < 1 || c > COLS

                continue;

            end


            %% 墙壁

            if maze(r,c) == '#'

                continue;

            end


            %% 已访问

            if visited(r,c)

                continue;

            end


            %% 加入 BFS 队列

            visited(r,c) = true;

            parentR(r,c) = current(1);

            parentC(r,c) = current(2);


            tail = tail + 1;

            queue(tail,:) = [r c];

        end

    end


    %% =====================================================
    %                 BFS没有找到路径
    % =====================================================

    if ~found

        return;

    end


    %% =====================================================
    %                 从终点反向追踪
    % =====================================================

    current = targetPos;

    path = current;


    while ~isequal(current,startPos)

        pr = parentR(current(1),current(2));

        pc = parentC(current(1),current(2));


        if pr == 0 || pc == 0

            nextStep = [];

            return;

        end


        current = [pr pc];

        path = [current;path]; %#ok<AGROW>

    end


    %% =====================================================
    %              path第二个点就是下一步
    % =====================================================

    if size(path,1) >= 2

        nextStep = path(2,:);

    else

        nextStep = startPos;

    end

end


%% =========================================================
%                         碰撞
% =========================================================

function checkGhostCollision()

    for g = 1:4

        if ~ghostActive(g) || ...
                ghostEaten(g)

            continue;

        end


        if isequal(playerPos,ghostPos(g,:))

            if frightened

                eatGhost(g);

            else

                loseLife();

            end

            return;

        end

    end

end


%% =========================================================
%                         吃鬼
% =========================================================

function eatGhost(g)

    ghostEaten(g) = true;

    ghostEatCount = ghostEatCount + 1;


    switch ghostEatCount

        case 1

            score = score + 200;

        case 2

            score = score + 400;

        case 3

            score = score + 800;

        otherwise

            score = score + 1600;

    end


    % 吃鬼音效
    playEffect(['ghost' num2str(min(ghostEatCount,4))]);


    if score >= 10000 && ~extraLifeGiven

        lives = lives + 1;

        extraLifeGiven = true;

        playEffect('extraLife');

    end

end


%% =========================================================
%                         玩家死亡
% =========================================================

function loseLife()

    lives = lives - 1;

    state = 'dead';

    deathTimer = tic;

    messageText.String = 'OUCH!';

    stopBGM();

    playEffect('death');

end


%% =========================================================
%                         检查过关
% =========================================================

function checkLevelClear()

    remaining = ...
        sum(pellets(:)) + ...
        sum(powerPellets(:));


    if remaining == 0

        state = 'levelclear';

        levelClearTimer = tic;

        messageText.String = ...
            sprintf('LEVEL %d CLEAR!',level);

        stopBGM();

        playEffect('levelClear');

    end

end


%% =========================================================
%                         下一关
% =========================================================

function nextLevel()

    level = level + 1;


    pellets = maze == '.';

    powerPellets = maze == 'o';


    frightened = false;

    frightenedTimer = [];

    frightenedDuration = 0;

    ghostEatCount = 0;


    frightenedText.String = '';


    mode = 'scatter';

    modeIndex = 1;

    modeClock = tic;

    ghostReleaseClock = tic;


    resetPositions();


    state = 'ready';

    readyTimer = tic;

    messageText.String = ...
        sprintf('LEVEL %d',level);


    playEffect('ready');

end


%% =========================================================
%                         重置位置
% =========================================================

function resetPositions()

    %% 玩家

    playerPos = [24 15];

    playerDir = [0 -1];

    wantedDir = [0 -1];


    %% 鬼

    ghostPos = [
        12 14
        15 12
        15 14
        15 16
    ];


    ghostDir = [
         0 -1
        -1  0
        -1  0
         1  0
    ];


    ghostActive = [
        true
        false
        false
        false
    ];


    ghostEaten(:) = false;


    ghostReleaseClock = tic;


    %% 模式

    mode = 'scatter';

    modeIndex = 1;

    modeClock = tic;


    %% Frightened

    frightened = false;

    frightenedTimer = [];

    frightenedDuration = 0;

    ghostEatCount = 0;


    frightenedText.String = '';


    %% 移动计时器

    playerMoveClock = tic;

    ghostMoveClock = tic;

end


%% =========================================================
%                         整局重新开始
% =========================================================

function resetWholeGame()

    score = 0;

    lives = START_LIVES;

    level = 1;

    extraLifeGiven = false;


    pellets = maze == '.';

    powerPellets = maze == 'o';


    state = 'ready';

    readyTimer = tic;


    stopBGM();

    resetPositions();


    messageText.String = 'READY!';


    playEffect('ready');

end


%% =========================================================
%                       玩家能否移动
% =========================================================

function tf = canPlayerMove(pos,dir)

    if isequal(dir,[0 0])

        tf = false;

        return;

    end


    next = wrapPosition(pos+dir);


    r = next(1);

    c = next(2);


    if r < 1 || r > ROWS || ...
       c < 1 || c > COLS

        tf = false;

        return;

    end


    if maze(r,c) == '#'

        tf = false;

        return;

    end


    %% 玩家不能进入鬼屋

    if r >= 13 && r <= 17 && ...
       c >= 11 && c <= 18

        tf = false;

        return;

    end


    tf = true;

end


%% =========================================================
%                       鬼能否移动
% =========================================================

function tf = canGhostMove(pos,dir)

    if isequal(dir,[0 0])

        tf = false;

        return;

    end


    next = wrapPosition(pos+dir);


    r = next(1);

    c = next(2);


    if r < 1 || r > ROWS || ...
       c < 1 || c > COLS

        tf = false;

        return;

    end


    tf = maze(r,c) ~= '#';

end


%% =========================================================
%                           隧道
% =========================================================

function p = wrapPosition(p)

    if p(1) == 15

        if p(2) < 1

            p(2) = COLS;

        elseif p(2) > COLS

            p(2) = 1;

        end

    end

end


%% =========================================================
%                         绘制地图
% =========================================================

function drawMaze()

    wallMask = maze == '#';

    [wr,wc] = find(wallMask);


    numWalls = numel(wr);

    vertices = zeros(numWalls*4,2);

    faces = zeros(numWalls,4);


    for k = 1:numWalls

        r = wr(k);

        c = wc(k);


        idx = (k-1)*4 + 1;


        vertices(idx,:) = ...
            [c-0.5 r-0.5];

        vertices(idx+1,:) = ...
            [c+0.5 r-0.5];

        vertices(idx+2,:) = ...
            [c+0.5 r+0.5];

        vertices(idx+3,:) = ...
            [c-0.5 r+0.5];


        faces(k,:) = idx:idx+3;

    end


    patch( ...
        ax, ...
        'Vertices',vertices, ...
        'Faces',faces, ...
        'FaceColor',[0.03 0.15 0.85], ...
        'EdgeColor','none');

end


%% =========================================================
%                        绘制游戏
% =========================================================

function drawGame()

    %% =====================================================
    %                       Pac-Man
    % ======================================================

    mouthOpen = ...
        mod(mouthPhase,4) < 2;


    [px,py] = pacmanShape( ...
        playerPos, ...
        playerDir, ...
        mouthOpen);


    playerHandle.XData = px;

    playerHandle.YData = py;


    %% =====================================================
    %                       普通豆
    % ======================================================

    [r,c] = find(pellets);

    pelletHandle.XData = c;

    pelletHandle.YData = r;


    %% =====================================================
    %                      Power Pellet
    % ======================================================

    [r,c] = find(powerPellets);

    powerHandle.XData = c;

    powerHandle.YData = r;


    if mod(floor(mouthPhase/3),2) == 0

        powerHandle.Visible = 'on';

    else

        powerHandle.Visible = 'off';

    end


    %% =====================================================
    %                          四只鬼
    % ======================================================

    for g = 1:4

        %% 没释放的鬼

        if ~ghostActive(g)

            ghostBody(g).Visible = 'off';

            ghostEyeWhite(g).Visible = 'off';

            ghostPupil(g).Visible = 'off';

            continue;

        end


        %% =================================================
        %                       被吃掉
        % ==================================================

        if ghostEaten(g)

            % 只显示眼睛
            ghostBody(g).Visible = 'off';

            ghostEyeWhite(g).Visible = 'on';

            ghostPupil(g).Visible = 'on';


        else

            ghostBody(g).Visible = 'on';


            [gx,gy] = ...
                ghostShape(ghostPos(g,:));


            ghostBody(g).XData = gx;

            ghostBody(g).YData = gy;


            %% ---------------------------------------------
            %                     正常颜色
            % ----------------------------------------------

            if ~frightened

                ghostBody(g).FaceColor = ...
                    ghostColors(g,:);


            else

                remaining = ...
                    frightenedDuration - ...
                    toc(frightenedTimer);


                if remaining <= 2

                    blink = ...
                        mod(floor(toc(frightenedTimer)*8),2);


                    if blink

                        ghostBody(g).FaceColor = ...
                            [1 1 1];

                    else

                        ghostBody(g).FaceColor = ...
                            [0.05 0.20 0.90];

                    end


                else

                    ghostBody(g).FaceColor = ...
                        [0.05 0.20 0.90];

                end

            end

        end


        %% =================================================
        %                         眼睛
        % ==================================================

        ed = ghostDir(g,:);


        eyeOffsetX = ed(2)*0.07;

        eyeOffsetY = ed(1)*0.07;


        t = linspace(0,2*pi,20);


        %% 左眼

        ex1 = ...
            ghostPos(g,2)-0.15 + ...
            eyeOffsetX + ...
            0.11*cos(t);

        ey1 = ...
            ghostPos(g,1)-0.10 + ...
            eyeOffsetY + ...
            0.11*sin(t);


        %% 右眼

        ex2 = ...
            ghostPos(g,2)+0.15 + ...
            eyeOffsetX + ...
            0.11*cos(t);

        ey2 = ...
            ghostPos(g,1)-0.10 + ...
            eyeOffsetY + ...
            0.11*sin(t);


        ghostEyeWhite(g).XData = ...
            [ex1 ex2];

        ghostEyeWhite(g).YData = ...
            [ey1 ey2];


        %% 瞳孔

        pupilOffsetX = ed(2)*0.045;

        pupilOffsetY = ed(1)*0.045;


        px1 = ...
            ghostPos(g,2)-0.15 + ...
            eyeOffsetX + ...
            pupilOffsetX + ...
            0.055*cos(t);

        py1 = ...
            ghostPos(g,1)-0.10 + ...
            eyeOffsetY + ...
            pupilOffsetY + ...
            0.055*sin(t);


        px2 = ...
            ghostPos(g,2)+0.15 + ...
            eyeOffsetX + ...
            pupilOffsetX + ...
            0.055*cos(t);

        py2 = ...
            ghostPos(g,1)-0.10 + ...
            eyeOffsetY + ...
            pupilOffsetY + ...
            0.055*sin(t);


        ghostPupil(g).XData = ...
            [px1 px2];

        ghostPupil(g).YData = ...
            [py1 py2];


        ghostEyeWhite(g).Visible = 'on';

        ghostPupil(g).Visible = 'on';

    end


    %% =====================================================
    %                           HUD
    % ======================================================

    scoreText.String = ...
        sprintf('SCORE  %06d',score);


    levelText.String = ...
        sprintf('LEVEL %d',level);


    livesText.String = ...
        makeHearts(lives);


    drawnow limitrate;

end


%% =========================================================
%                         生命
% =========================================================

function s = makeHearts(n)

    if n <= 0

        s = '';

    else

        s = repmat('♥ ',1,n);

        s = strtrim(s);

    end

end


%% =========================================================
%                        Pac-Man造型
% =========================================================

function [x,y] = pacmanShape(pos,dir,openMouth)

    cx = pos(2);

    cy = pos(1);

    radius = 0.43;


    if isequal(dir,[0 1])

        angle = 0;

    elseif isequal(dir,[1 0])

        angle = pi/2;

    elseif isequal(dir,[0 -1])

        angle = pi;

    else

        angle = -pi/2;

    end


    if openMouth

        mouth = pi/5;

    else

        mouth = 0;

    end


    if mouth == 0

        theta = linspace(0,2*pi,32);

        x = cx + radius*cos(theta);

        y = cy + radius*sin(theta);

        return;

    end


    theta = linspace( ...
        angle+mouth, ...
        angle+2*pi-mouth, ...
        30);


    x = [
        cx ...
        cx + radius*cos(theta) ...
        cx
    ];


    y = [
        cy ...
        cy + radius*sin(theta) ...
        cy
    ];

end


%% =========================================================
%                           鬼造型
% =========================================================

function [x,y] = ghostShape(pos)

    cx = pos(2);
    cy = pos(1);

    R = 0.48;

    theta = linspace(pi,0,40);

    topX = cx + R*cos(theta);
    topY = cy - R*sin(theta);


    bottomX = [
        cx + R
        cx + R
        cx + 0.36
        cx + 0.24
        cx + 0.12
        cx
        cx - 0.12
        cx - 0.24
        cx - 0.36
        cx - R
        cx - R
    ];


    bottomY = [
        cy
        cy + 0.28
        cy + 0.40
        cy + 0.28
        cy + 0.40
        cy + 0.28
        cy + 0.40
        cy + 0.28
        cy + 0.40
        cy + 0.28
        cy
    ];


    x = [topX, bottomX'];

    y = [topY, bottomY'];

end


%% =========================================================
%                    创建所有程序音效
% =========================================================

function sounds = createSoundEffects(fs)

    sounds = struct();


    %% =====================================================
    %                     普通豆 1
    % =====================================================

    sounds.pellet1 = makeTone( ...
        [760 620], ...
        [0.045 0.045], ...
        fs, ...
        0.22);


    %% =====================================================
    %                     普通豆 2
    % =====================================================

    sounds.pellet2 = makeTone( ...
        [620 760], ...
        [0.045 0.045], ...
        fs, ...
        0.22);


    %% =====================================================
    %                     Power Pellet
    % =====================================================

    sounds.power = makeSweep( ...
        260, ...
        700, ...
        0.28, ...
        fs, ...
        0.30);


    %% =====================================================
    %                     吃鬼 1
    % =====================================================

    sounds.ghost1 = makeTone( ...
        [900 1150], ...
        [0.08 0.12], ...
        fs, ...
        0.38);


    %% =====================================================
    %                     吃鬼 2
    % =====================================================

    sounds.ghost2 = makeTone( ...
        [900 1200 1500], ...
        [0.07 0.07 0.12], ...
        fs, ...
        0.42);


    %% =====================================================
    %                     吃鬼 3
    % =====================================================

    sounds.ghost3 = makeTone( ...
        [950 1250 1550 1800], ...
        [0.06 0.06 0.06 0.12], ...
        fs, ...
        0.45);


    %% =====================================================
    %                     吃鬼 4
    % =====================================================

    sounds.ghost4 = makeTone( ...
        [1100 1400 1700 2000 2300], ...
        [0.05 0.05 0.05 0.05 0.12], ...
        fs, ...
        0.50);


    %% =====================================================
    %                       死亡
    % =====================================================

    sounds.death = makeDeathSound(fs);


    %% =====================================================
    %                       过关
    % =====================================================

    sounds.levelClear = makeTone( ...
        [523 659 784 1047 1319], ...
        [0.10 0.10 0.10 0.10 0.20], ...
        fs, ...
        0.42);


    %% =====================================================
    %                       READY
    % =====================================================

    sounds.ready = makeTone( ...
        [523 659 784], ...
        [0.10 0.10 0.20], ...
        fs, ...
        0.30);


    %% =====================================================
    %                     额外生命
    % =====================================================

    sounds.extraLife = makeTone( ...
        [784 988 1175 1568], ...
        [0.08 0.08 0.08 0.18], ...
        fs, ...
        0.40);

end


%% =========================================================
%                       播放音效
% =========================================================

function playEffect(name)

    if ~audioEnabled
        return;
    end


    if ~isfield(soundData,name)
        return;
    end


    try

        player = audioplayer( ...
            soundData.(name), ...
            audioFS);


        soundPlayers{end+1} = player;

        play(player);


        % 清理已经播放完成的对象
        cleanupSoundPlayers();

    catch

        % 如果声音系统不可用，不影响游戏运行

    end

end


%% =========================================================
%                  清理已经结束的音效
% =========================================================

function cleanupSoundPlayers()

    if isempty(soundPlayers)
        return;
    end


    keep = true(1,numel(soundPlayers));


    for k = 1:numel(soundPlayers)

        try

            if ~isplaying(soundPlayers{k})

                keep(k) = false;

            end

        catch

            keep(k) = false;

        end

    end


    soundPlayers = soundPlayers(keep);

end


%% =========================================================
%                       启动 BGM
% =========================================================

function startBGM()

    if ~audioEnabled
        return;
    end


    if isempty(bgmPlayer)

        return;

    end


    try

        bgmShouldLoop = true;

        play(bgmPlayer);

    catch

    end

end


%% =========================================================
%                       暂停 BGM
% =========================================================

function pauseBGM()

    if isempty(bgmPlayer)
        return;
    end


    try

        bgmShouldLoop = false;

        pause(bgmPlayer);

    catch

    end

end


%% =========================================================
%                       恢复 BGM
% =========================================================

function resumeBGM()

    if ~audioEnabled || isempty(bgmPlayer)

        return;

    end


    try

        bgmShouldLoop = true;

        play(bgmPlayer);

    catch

    end

end


%% =========================================================
%                       停止 BGM
% =========================================================

function stopBGM()

    if isempty(bgmPlayer)
        return;
    end


    try

        bgmShouldLoop = false;

        stop(bgmPlayer);

    catch

    end

end


%% =========================================================
%                     BGM 自动循环
% =========================================================

function bgmLoop(~,~)

    if ~audioEnabled
        return;
    end


    if ~bgmShouldLoop
        return;
    end


    if ~isvalid(fig)
        return;
    end


    if ~strcmp(state,'playing')
        return;
    end


    try

        play(bgmPlayer);

    catch

    end

end


%% =========================================================
%                      音调生成器
% =========================================================

function y = makeTone(freqs,durations,fs,volume)

    y = [];


    for k = 1:numel(freqs)

        n = max(1,round(durations(k)*fs));

        t = (0:n-1)/fs;


        tone = sin(2*pi*freqs(k)*t);


        % 平滑淡入淡出
        env = ones(size(t));

        fadeN = min(round(0.008*fs),floor(n/2));


        if fadeN > 1

            fade = linspace(0,1,fadeN);

            env(1:fadeN) = fade;

            env(end-fadeN+1:end) = fliplr(fade);

        end


        tone = tone .* env;

        y = [y tone]; %#ok<AGROW>

    end


    y = volume*y;

end


%% =========================================================
%                       扫频音效
% =========================================================

function y = makeSweep(f1,f2,duration,fs,volume)

    n = round(duration*fs);

    t = (0:n-1)/fs;


    freq = linspace(f1,f2,n);


    phase = 2*pi*cumsum(freq)/fs;


    y = sin(phase);


    % 音量包络
    env = ones(size(t));

    fadeN = min(round(0.015*fs),floor(n/2));


    if fadeN > 1

        fade = linspace(0,1,fadeN);

        env(1:fadeN) = fade;

        env(end-fadeN+1:end) = fliplr(fade);

    end


    y = volume*y.*env;

end


%% =========================================================
%                       死亡音效
% =========================================================

function y = makeDeathSound(fs)

    duration = 0.90;

    n = round(duration*fs);

    t = (0:n-1)/fs;


    % 连续下降频率
    f1 = 720;

    f2 = 90;


    freq = linspace(f1,f2,n);

    phase = 2*pi*cumsum(freq)/fs;


    y = sin(phase);


    % 第二谐波增加一点经典游戏感
    y = y + 0.22*sin(2*phase);


    % 逐渐消失
    env = linspace(1,0,n);


    y = 0.42*y.*env;

end


%% =========================================================
%                          关闭程序
% ==========================================================

function closeGame(~,~)

    %% 停止 BGM

    try

        bgmShouldLoop = false;

        if ~isempty(bgmPlayer)

            stop(bgmPlayer);

        end

    catch

    end


    %% 停止所有音效

    try

        for k = 1:numel(soundPlayers)

            if ~isempty(soundPlayers{k})

                try

                    stop(soundPlayers{k});

                catch

                end

            end

        end

    catch

    end


    %% 删除 Timer

    try

        if exist('gameTimer','var') && ...
                isvalid(gameTimer)

            stop(gameTimer);

            delete(gameTimer);

        end

    catch

    end


    %% 删除窗口

    try

        if isvalid(fig)

            delete(fig);

        end

    catch

    end

end


end