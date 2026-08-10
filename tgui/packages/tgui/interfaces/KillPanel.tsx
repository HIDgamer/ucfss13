import { useBackend } from '../backend';
import { Box, Collapsible, NoticeBox, Section } from '../components';
import { Window } from '../layouts';

type DeathEntry = {
  mob_name: string;
  job_name: string;
  area_name: string;
  cause_name: string;
  total_kills: number;
  total_damage: { name: string; value: number }[];
  time_of_death: string;
  total_time_alive: string;
  total_damage_taken: number;
  x: number;
  y: number;
  z: number;
};

type Data = {
  death_data: {
    death_stats_list?: DeathEntry[];
  };
};

export const KillPanel = (props) => {
  const { act, data } = useBackend<Data>();
  const { death_data } = data;

  const hasKills = !!death_data?.death_stats_list?.length;

  return (
    <Window width={300} height={600}>
      <Window.Content scrollable>
        <Section>
          {hasKills ? (
            <KillView />
          ) : (
            <NoticeBox danger>No recorded kills!</NoticeBox>
          )}
        </Section>
      </Window.Content>
    </Window>
  );
};

const KillView = (props) => {
  const { act, data } = useBackend<Data>();
  const { death_data } = data;

  const real_data = death_data.death_stats_list ?? [];

  return real_data.map((entry, index) => (
    <Collapsible
      key={index}
      title={entry.mob_name + ' (' + entry.time_of_death + ')'}
    >
      <Box>Mob: {entry.mob_name}</Box>
      {entry.job_name ? (
        <>
          <Box height="3px" />
          <Box>Job: {entry.job_name}</Box>
        </>
      ) : null}
      <Box height="3px" />
      <Box>Area: {entry.area_name}</Box>
      <Box height="3px" />
      <Box>Cause: {entry.cause_name}</Box>
      <Box height="3px" />
      <Box>Time: {entry.time_of_death}</Box>
      <Box height="3px" />
      <Box>Lifespan: {entry.total_time_alive}</Box>
      <Box height="3px" />
      <Box>Damage taken: {entry.total_damage_taken}</Box>
      <Box height="3px" />
      <Box>
        Coords: {entry.x}, {entry.y}, {entry.z}
      </Box>
    </Collapsible>
  ));
};
