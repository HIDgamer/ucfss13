import { sortBy } from 'common/collections';
import { useMemo, useState } from 'react';

import { useBackend } from '../backend';
import { Box, Button, Icon, Input, Section, Stack } from '../components';
import { COLORS } from '../constants';
import { Window } from '../layouts';

// Map ijob ranges to department groups
const DEPT_GROUPS = [
  { key: 'all', label: 'ALL', color: '#888', min: -Infinity, max: Infinity },
  {
    key: 'command',
    label: 'CMD',
    color: COLORS.shipDeps.command,
    min: 0,
    max: 29,
  },
  {
    key: 'security',
    label: 'SEC',
    color: COLORS.shipDeps.security,
    min: 30,
    max: 39,
  },
  {
    key: 'medical',
    label: 'MED',
    color: COLORS.shipDeps.medsci,
    min: 40,
    max: 49,
  },
  {
    key: 'engineering',
    label: 'ENG',
    color: COLORS.shipDeps.engineering,
    min: 50,
    max: 59,
  },
  {
    key: 'cargo',
    label: 'REQ',
    color: COLORS.shipDeps.cargo,
    min: 60,
    max: 69,
  },
  {
    key: 'alpha',
    label: 'ALPHA',
    color: COLORS.shipDeps.alpha,
    min: 70,
    max: 79,
  },
  {
    key: 'bravo',
    label: 'BRAVO',
    color: COLORS.shipDeps.bravo,
    min: 80,
    max: 89,
  },
  {
    key: 'charlie',
    label: 'CHARLIE',
    color: COLORS.shipDeps.charlie,
    min: 90,
    max: 99,
  },
  {
    key: 'delta',
    label: 'DELTA',
    color: COLORS.shipDeps.delta,
    min: 100,
    max: 109,
  },
  {
    key: 'echo',
    label: 'ECHO',
    color: COLORS.shipDeps.echo,
    min: 110,
    max: 119,
  },
  {
    key: 'foxtrot',
    label: 'FTX',
    color: COLORS.shipDeps.foxtrot,
    min: 120,
    max: 129,
  },
  {
    key: 'raiders',
    label: 'RAID',
    color: COLORS.shipDeps.raiders,
    min: 130,
    max: 139,
  },
  { key: 'other', label: 'OTH', color: '#777', min: 140, max: 9998 },
];

const getDeptForJob = (ijob) =>
  DEPT_GROUPS.find((d) => d.key !== 'all' && ijob >= d.min && ijob <= d.max) ||
  DEPT_GROUPS[DEPT_GROUPS.length - 1];

const getDamageSum = (s) =>
  (s.oxydam || 0) + (s.toxdam || 0) + (s.burndam || 0) + (s.brutedam || 0);

const getStatusInfo = (sensor) => {
  const dmg = getDamageSum(sensor);
  const dead =
    sensor.stat === 2 ||
    (sensor.stat === undefined && sensor.life_status === false);
  const unconsious = sensor.stat === 1;
  const permadead = dead && dmg >= 200;

  if (permadead) {
    return {
      overlay: 'rgba(0,0,0,0.6)',
      label: 'PERM',
      icon: 'skull',
      pulse: false,
    };
  }
  if (dead) {
    return {
      overlay: 'rgba(160,0,0,0.35)',
      label: 'DEAD',
      icon: 'skull',
      pulse: false,
    };
  }
  if (unconsious) {
    return {
      overlay: 'rgba(180,60,0,0.3)',
      label: 'DOWN',
      icon: 'bed',
      pulse: true,
    };
  }
  if (dmg >= 100) {
    return {
      overlay: 'rgba(180,80,0,0.2)',
      label: 'CRIT',
      icon: 'heart',
      pulse: true,
    };
  }
  if (dmg >= 50) {
    return {
      overlay: 'rgba(160,150,0,0.18)',
      label: 'WND',
      icon: 'heart',
      pulse: false,
    };
  }
  return { overlay: null, label: 'OK', icon: 'heart', pulse: false };
};

const Portrait = ({ ijob, statusInfo }) => {
  const dept = getDeptForJob(ijob);
  const isDead = statusInfo.label === 'DEAD' || statusInfo.label === 'PERM';
  return (
    <Box
      style={{
        width: '2.2rem',
        height: '2.2rem',
        minWidth: '2.2rem',
        backgroundColor: dept.color,
        borderRadius: '3px',
        position: 'relative',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        opacity: isDead ? 0.7 : 1,
        transition: 'opacity 0.4s ease',
        overflow: 'hidden',
        flexShrink: 0,
      }}
    >
      <Icon
        name="user"
        style={{ color: 'rgba(255,255,255,0.75)', fontSize: '1.1rem' }}
      />
      {isDead && (
        <Box
          style={{
            position: 'absolute',
            inset: 0,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            backgroundColor: 'rgba(0,0,0,0.45)',
          }}
        >
          <Icon
            name="times"
            style={{ color: '#ff4444', fontSize: '1.4rem', fontWeight: 'bold' }}
          />
        </Box>
      )}
    </Box>
  );
};

const HealthBar = ({ oxydam, toxdam, burndam, brutedam }) => {
  if (
    oxydam === undefined &&
    toxdam === undefined &&
    burndam === undefined &&
    brutedam === undefined
  ) {
    return null;
  }
  const total = Math.min(oxydam + toxdam + burndam + brutedam, 400);
  const pct = total / 400;
  const barColor =
    pct < 0.25
      ? '#2ecc71'
      : pct < 0.5
        ? '#f1c40f'
        : pct < 0.75
          ? '#e67e22'
          : '#e74c3c';
  return (
    <Box
      style={{
        width: '4rem',
        height: '6px',
        backgroundColor: 'rgba(255,255,255,0.12)',
        borderRadius: '3px',
        overflow: 'hidden',
        marginTop: '2px',
      }}
    >
      <Box
        style={{
          width: `${(1 - pct) * 100}%`,
          height: '100%',
          backgroundColor: barColor,
          transition: 'width 0.6s ease, background-color 0.4s ease',
          borderRadius: '3px',
        }}
      />
    </Box>
  );
};

const VitalNums = ({ oxydam, toxdam, burndam, brutedam }) => {
  if (oxydam === undefined) return null;
  return (
    <Box style={{ fontSize: '0.65rem', lineHeight: 1.3 }}>
      <Box style={{ display: 'flex', gap: '4px' }}>
        <Box
          as="span"
          style={{ color: COLORS.damageType.oxy, minWidth: '2rem' }}
        >
          O:{oxydam}
        </Box>
        <Box as="span" style={{ color: COLORS.damageType.toxin }}>
          T:{toxdam}
        </Box>
      </Box>
      <Box style={{ display: 'flex', gap: '4px' }}>
        <Box
          as="span"
          style={{ color: COLORS.damageType.burn, minWidth: '2rem' }}
        >
          B:{burndam}
        </Box>
        <Box as="span" style={{ color: COLORS.damageType.brute }}>
          Br:{brutedam}
        </Box>
      </Box>
    </Box>
  );
};

const CrewRow = ({ sensor, link_allowed, act }) => {
  const statusInfo = getStatusInfo(sensor);
  const dept = getDeptForJob(sensor.ijob);
  const isHead = sensor.ijob % 10 === 0 && sensor.ijob !== 999;

  return (
    <Box
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: '0.5rem',
        padding: '0.3rem 0.4rem',
        marginBottom: '2px',
        borderRadius: '3px',
        position: 'relative',
        backgroundColor: statusInfo.overlay || 'rgba(255,255,255,0.03)',
        transition: 'background-color 0.5s ease',
        borderLeft: `3px solid ${dept.color}`,
        animation: statusInfo.pulse
          ? 'crew-row-pulse 2s ease-in-out infinite'
          : 'none',
      }}
    >
      <Portrait ijob={sensor.ijob} statusInfo={statusInfo} />

      {/* Name & assignment */}
      <Box style={{ flex: 1, minWidth: 0 }}>
        <Box
          style={{
            fontWeight: isHead ? 'bold' : 'normal',
            color: dept.color,
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            fontSize: '0.9rem',
          }}
        >
          {sensor.name}
        </Box>
        {sensor.assignment !== undefined && (
          <Box
            style={{
              fontSize: '0.7rem',
              color: 'rgba(255,255,255,0.5)',
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            {sensor.assignment}
          </Box>
        )}
      </Box>

      {/* Status badge */}
      <Box
        style={{
          fontSize: '0.65rem',
          fontWeight: 'bold',
          color:
            statusInfo.label === 'PERM'
              ? '#888'
              : statusInfo.label === 'DEAD'
                ? '#ff6060'
                : statusInfo.label === 'DOWN' || statusInfo.label === 'CRIT'
                  ? '#ffaa44'
                  : statusInfo.label === 'WND'
                    ? '#ffe060'
                    : '#4cff88',
          width: '3rem',
          textAlign: 'center',
          flexShrink: 0,
        }}
      >
        <Icon name={statusInfo.icon} style={{ marginRight: '2px' }} />
        {statusInfo.label}
      </Box>

      {/* Vitals */}
      <Box style={{ width: '5rem', flexShrink: 0, overflow: 'hidden' }}>
        <VitalNums
          oxydam={sensor.oxydam}
          toxdam={sensor.toxdam}
          burndam={sensor.burndam}
          brutedam={sensor.brutedam}
        />
        <HealthBar
          oxydam={sensor.oxydam}
          toxdam={sensor.toxdam}
          burndam={sensor.burndam}
          brutedam={sensor.brutedam}
        />
      </Box>

      {/* Location */}
      <Box
        style={{
          width: '7rem',
          fontSize: '0.7rem',
          color:
            sensor.side !== undefined
              ? COLORS.damageType.oxy
              : 'rgba(255,255,255,0.5)',
          whiteSpace: 'nowrap',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
          flexShrink: 0,
        }}
      >
        {sensor.area !== undefined ? (
          sensor.area
        ) : (
          <Icon name="question" style={{ color: 'rgba(255,255,255,0.3)' }} />
        )}
      </Box>

      {/* Track button */}
      {!!link_allowed && (
        <Button
          icon="crosshairs"
          disabled={!sensor.can_track}
          tooltip="Track"
          onClick={() => act('select_person', { name: sensor.name })}
          style={{ flexShrink: 0 }}
        />
      )}
    </Box>
  );
};

export const CrewConsole = () => {
  const { act, data } = useBackend();
  const { sensors = [], link_allowed } = data;
  const [search, setSearch] = useState('');
  const [activeTab, setActiveTab] = useState('all');

  const sorted = useMemo(() => sortBy(sensors, (s) => s.ijob), [sensors]);

  // Build tab list: only show tabs with entries
  const availableTabs = useMemo(() => {
    const present = new Set(sorted.map((s) => getDeptForJob(s.ijob).key));
    return DEPT_GROUPS.filter((g) => g.key === 'all' || present.has(g.key));
  }, [sorted]);

  const filtered = useMemo(() => {
    const q = search.toLowerCase();
    return sorted.filter((s) => {
      const inTab =
        activeTab === 'all' || getDeptForJob(s.ijob).key === activeTab;
      const inSearch =
        !q ||
        (s.name || '').toLowerCase().includes(q) ||
        (s.assignment || '').toLowerCase().includes(q);
      return inTab && inSearch;
    });
  }, [sorted, activeTab, search]);

  return (
    <Window title="Crew Monitor" width={680} height={580}>
      <style>
        {`
        @keyframes crew-row-pulse {
          0% { filter: brightness(1); }
          50% { filter: brightness(1.18); }
          100% { filter: brightness(1); }
        }
      `}
      </style>
      <Window.Content>
        <Stack vertical fill>
          {/* Search bar */}
          <Stack.Item>
            <Input
              fluid
              placeholder="Search by name or assignment…"
              value={search}
              onInput={(e, v) => setSearch(v)}
            />
          </Stack.Item>

          {/* Department/squad tabs */}
          <Stack.Item>
            <Box
              style={{
                display: 'flex',
                flexWrap: 'wrap',
                gap: '3px',
                paddingBottom: '4px',
              }}
            >
              {availableTabs.map((tab) => (
                <Box
                  key={tab.key}
                  as="button"
                  onClick={() => setActiveTab(tab.key)}
                  style={{
                    padding: '2px 8px',
                    borderRadius: '3px',
                    border:
                      activeTab === tab.key
                        ? `2px solid ${tab.color}`
                        : '2px solid rgba(255,255,255,0.1)',
                    backgroundColor:
                      activeTab === tab.key
                        ? tab.color
                        : 'rgba(255,255,255,0.04)',
                    color:
                      activeTab === tab.key ? '#fff' : 'rgba(255,255,255,0.6)',
                    fontSize: '0.7rem',
                    fontWeight: 'bold',
                    cursor: 'pointer',
                    transition: 'all 0.15s ease',
                    letterSpacing: '0.5px',
                  }}
                >
                  {tab.label}
                </Box>
              ))}
            </Box>
          </Stack.Item>

          {/* Column headers */}
          <Stack.Item>
            <Box
              style={{
                display: 'flex',
                gap: '0.5rem',
                padding: '0 0.4rem',
                fontSize: '0.65rem',
                color: 'rgba(255,255,255,0.35)',
                letterSpacing: '1px',
                textTransform: 'uppercase',
                paddingBottom: '4px',
                borderBottom: '1px solid rgba(255,255,255,0.08)',
              }}
            >
              <Box style={{ width: '2.2rem', flexShrink: 0 }}>ID</Box>
              <Box style={{ flex: 1 }}>Name / Assignment</Box>
              <Box
                style={{ width: '3rem', textAlign: 'center', flexShrink: 0 }}
              >
                Status
              </Box>
              <Box style={{ width: '5rem', flexShrink: 0 }}>Vitals</Box>
              <Box style={{ width: '7rem', flexShrink: 0 }}>Location</Box>
              {!!link_allowed && (
                <Box style={{ width: '2.5rem', flexShrink: 0 }}>Track</Box>
              )}
            </Box>
          </Stack.Item>

          {/* Crew list */}
          <Stack.Item grow basis={0} style={{ overflowY: 'auto' }}>
            <Section fitted>
              {filtered.length === 0 ? (
                <Box
                  style={{
                    textAlign: 'center',
                    color: 'rgba(255,255,255,0.3)',
                    padding: '2rem',
                    fontStyle: 'italic',
                  }}
                >
                  No crew found
                </Box>
              ) : (
                filtered.map((sensor) => (
                  <CrewRow
                    key={sensor.ref}
                    sensor={sensor}
                    link_allowed={link_allowed}
                    act={act}
                  />
                ))
              )}
            </Section>
          </Stack.Item>

          {/* Footer stats */}
          <Stack.Item>
            <Box
              style={{
                fontSize: '0.7rem',
                color: 'rgba(255,255,255,0.35)',
                textAlign: 'right',
                borderTop: '1px solid rgba(255,255,255,0.08)',
                paddingTop: '4px',
              }}
            >
              {filtered.length} / {sorted.length} crew
            </Box>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
