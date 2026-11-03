%% [R2r2-13] R2r2_13_figure2_draw.m
%  Draws the revised Figure 2 with amateur and professional participants in the same panels.
%  Output : revision/results/fig2r2_*.svg, fig2r2_*.png

clc; clear; close all;
thisDir = fileparts(mfilename('fullpath')); if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');
T = readtable(fullfile(RES, 'R2r2_13_figure2_d_mocap.csv'), 'TextType', 'string');

CA = R2_participant_colors(10);
CP = [ 13  51 140;  26 140 140;  51 153 242;   0 115 179;   0 166 217; ...
       26 102 204; 102 179 242;  77  77 191;  13  89 153 ] / 255;
FONT = 'Gill Sans MT';
if ~any(strcmp(listfonts, FONT)), FONT = 'Arial'; end
LIM = [-7 25];
G = struct('name', {"Amateur", "Professional"}, 'C', {CA, CP}, 'mk', {'o', '^'});

fig = figure('Units', 'points', 'Position', [50 50 250 230], 'Color', 'w');
ax = axes(fig, 'Units', 'points', 'Position', [34 30 200 190]); hold(ax, 'on');
for g = G
    Tg = T(T.group == g.name, :);
    for s = unique(Tg.subj)'
        k = Tg.subj == s; c = g.C(s,:);
        scatter3(ax, Tg.dx(k), Tg.dy(k), Tg.dz(k), 9, c, g.mk, 'filled', ...
            'MarkerFaceAlpha', 0.55, 'MarkerEdgeColor', 'none');
        m = [mean(Tg.dx(k)) mean(Tg.dy(k)) mean(Tg.dz(k))];
        quiver3(ax, 0, 0, 0, m(1), m(2), m(3), 0, 'Color', c, 'LineWidth', 0.9, ...
            'MaxHeadSize', 0.12);
    end
end
plot3(ax, 0, 0, 0, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 3.5);
text(ax, 0, 0, -1.6, 'ADD', 'FontName', FONT, 'FontSize', 8, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
xlim(ax, [-5 20]); ylim(ax, [-5 20]); zlim(ax, [0 25]);
xticks(ax, 10:10:20); yticks(ax, 10:10:20); zticks(ax, 0:10:20);
view(ax, -38, 18); grid(ax, 'on'); box(ax, 'off');
set(ax, 'FontName', FONT, 'FontSize', 8, 'GridAlpha', 0.15, 'LineWidth', 0.6, ...
    'DataAspectRatio', [1 1 1], 'Projection', 'orthographic');
xlabel(ax, 'X (cm)', 'FontSize', 10); ylabel(ax, 'Y (cm)', 'FontSize', 10);
zlabel(ax, 'Z (cm)', 'FontSize', 10);
local_save(fig, RES, 'fig2r2_3d');

P = {'xz', 1, 3, 'X (cm)', 'Z (cm)'; 'xy', 1, 2, 'X (cm)', 'Y (cm)'; 'yz', 2, 3, 'Y (cm)', 'Z (cm)'};
th = linspace(0, 2*pi, 80);
for pi_ = 1:size(P,1)
    fig = figure('Units', 'points', 'Position', [50 50 140 140], 'Color', 'w');
    ax = axes(fig, 'Units', 'points', 'Position', [30 28 104 104]); hold(ax, 'on');
    a = P{pi_,2}; b = P{pi_,3};
    for g = G
        Tg = T(T.group == g.name, :);
        V = [Tg.dx Tg.dy Tg.dz];
        for s = unique(Tg.subj)'
            k = Tg.subj == s; c = g.C(s,:);
            scatter(ax, V(k,a), V(k,b), 6, c, g.mk, 'filled', ...
                'MarkerFaceAlpha', 0.55, 'MarkerEdgeColor', 'none');
            mu = mean(V(k,:), 1); sd = std(V(k,:), 0, 1);
            plot(ax, mu(a) + sd(a)*cos(th), mu(b) + sd(b)*sin(th), '-', ...
                'Color', c, 'LineWidth', 0.8);
        end
    end
    plot(ax, 0, 0, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 3);
    xline(ax, 0, 'k-', 'LineWidth', 0.6); yline(ax, 0, 'k-', 'LineWidth', 0.6);
    xlim(ax, LIM); ylim(ax, LIM); xticks(ax, 0:10:20); yticks(ax, 0:10:20);
    ax.XAxis.MinorTickValues = -5:5:25; ax.YAxis.MinorTickValues = -5:5:25;
    grid(ax, 'on'); ax.XMinorGrid = 'on'; ax.YMinorGrid = 'on';
    set(ax, 'FontName', FONT, 'FontSize', 8, 'GridAlpha', 0.15, 'MinorGridAlpha', 0.15, ...
        'MinorGridLineStyle', '-', 'LineWidth', 0.6, 'Box', 'on', 'TickLength', [0 0], ...
        'XColor', [0.6 0.6 0.6], 'YColor', [0.6 0.6 0.6]);
    ax.TickLabelInterpreter = 'tex';
    xticklabels(ax, {'\color{black}0', '\color{black}10', '\color{black}20'});
    yticklabels(ax, {'\color{black}0', '\color{black}10', '\color{black}20'});
    ax.XAxis.Label.Color = 'k'; ax.YAxis.Label.Color = 'k';
    xlabel(ax, P{pi_,4}, 'FontSize', 10); ylabel(ax, P{pi_,5}, 'FontSize', 10);
    text(ax, -0.6, -0.6, 'ADD', 'FontName', FONT, 'FontSize', 7, ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');
    local_save(fig, RES, ['fig2r2_' P{pi_,1}]);
end
fprintf('font: %s\n', FONT);

function local_save(fig, RES, name)
    print(fig, fullfile(RES, [name '.svg']), '-dsvg', '-vector');
    exportgraphics(fig, fullfile(RES, [name '.png']), 'Resolution', 600);
end
