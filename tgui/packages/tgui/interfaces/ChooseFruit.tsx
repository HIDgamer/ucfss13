import { classes } from 'common/react';
import { useState } from 'react';

import { useBackend } from '../backend';
import { Box, Button, Section, Stack, Tabs } from '../components';
import { Window } from '../layouts';

type Fruit = {
  name: string;
  desc: string;
  image: string;
  id: string;
};

type Data = {
  fruits: Fruit[];
  selected_fruit: string;
};

export const ChooseFruit = (props) => {
  const { act, data } = useBackend<Data>();
  const { fruits, selected_fruit } = data;

  const [compact, setCompact] = useState(false);

  let heightScale = 80;
  if (compact) heightScale = 45;

  return (
    <Window
      width={350}
      height={Math.min(15 + fruits.length * heightScale, 600)}
      theme="hive_status"
    >
      <Window.Content>
        <Section
          title="Fruits"
          buttons={
            <Button
              color="transparent"
              tooltip="Compact Mode"
              tooltipPosition="left"
              selected={compact}
              onClick={() => {
                setCompact(!compact);
                act('refresh_ui');
              }}
              icon="compress-arrows-alt"
            />
          }
          scrollable
          fill
        >
          <Tabs vertical fluid fill>
            {fruits.map((val, index) => (
              <Tabs.Tab
                key={index}
                selected={val.id === selected_fruit}
                onClick={() => act('choose_fruit', { type: val.id })}
              >
                <Stack align="center">
                  <Stack.Item>
                    <span
                      className={classes([
                        `choosefruit${compact ? '32x32' : '64x64'}`,
                        `${val.image}${compact ? '' : '_big'}`,
                        'ChooseResin__BuildIcon',
                      ])}
                    />
                  </Stack.Item>
                  <Stack.Item grow>
                    {/* NOTE: original .jsx had `<Box fontSiz>` -- "fontSiz" is
                        not a real Box prop (typo for fontSize), so it never
                        did anything; dropped since it doesn't type-check.
                        See report. */}
                    <Box>{val.name}</Box>
                  </Stack.Item>
                </Stack>
              </Tabs.Tab>
            ))}
          </Tabs>
        </Section>
      </Window.Content>
    </Window>
  );
};
