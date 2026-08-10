import { hexToHsva, HsvaColor, hsvaToHex } from 'common/color';
import { useState } from 'react';

import { useBackend } from '../backend';
import {
  Box,
  Button,
  ColorBox,
  DmIcon,
  Modal,
  Section,
  Stack,
  Tooltip,
} from '../components';
import { Window } from '../layouts';
import { ColorSelector } from './ColorPickerModal';

type PickerData = {
  icon: string;
  body_types: { name: string; icon: string }[];
  skin_colors: { name: string; icon: string }[];

  body_type: string;
  skin_color: string;
  gender: string;
  eye_color: string;
};

export const BodyPicker = () => {
  const { act, data } = useBackend<PickerData>();

  const { icon, gender, body_type, skin_color, body_types, eye_color } = data;

  const [typePicker, setTypePicker] = useState(false);
  const [eyeColorPicker, setEyeColorPicker] = useState(false);

  return (
    <Window width={420} height={420} theme={'crtlobby'}>
      <Window.Content className="BodyPicker" scrollable>
        {typePicker && (
          <Modal m={1}>
            <TypePicker close={() => setTypePicker(false)} />
          </Modal>
        )}
        {eyeColorPicker && (
          <EyeColorPicker
            close={() => setEyeColorPicker(false)}
            default_color={eye_color}
          />
        )}
        <Stack vertical>
          <Stack.Item>
            <Section title="Body">
              <Stack align="center">
                <Stack.Item>
                  <DmIcon
                    icon={icon}
                    icon_state={`${skin_color}_torso_${body_type}_${gender}`}
                    width={'128px'}
                  />
                </Stack.Item>
                <Stack.Item grow>
                  <Stack vertical>
                    <Stack.Item>
                      <Button
                        fluid
                        icon="person"
                        onClick={() => setTypePicker(true)}
                      >
                        Change Body Type
                      </Button>
                    </Stack.Item>
                    <Stack.Item>
                      <Button
                        fluid
                        icon="venus-mars"
                        onClick={() => act('gender')}
                      >
                        {gender === 'm' ? 'Male' : 'Female'}
                      </Button>
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>
          <Stack.Item>
            <Section title="Skin Color">
              <ColorOptions />
            </Section>
          </Stack.Item>
          <Stack.Item>
            <Section title="Eyes">
              <Button onClick={() => setEyeColorPicker(true)}>
                <ColorBox color={eye_color} mr={1} />
                Eye Color
              </Button>
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

const TypePicker = (props: { readonly close: () => void }) => {
  const { data, act } = useBackend<PickerData>();
  const { close } = props;

  const { body_type, body_types, skin_color, gender, icon } = data;

  return (
    <Section title="Body Type" buttons={<Button icon="xmark" onClick={close} />}>
      <Stack>
        {body_types.map((type) => (
          <Stack.Item key={type.name}>
            <Tooltip content={type.name}>
              <Box
                onClick={() => {
                  close();
                  act('type', { name: type.name });
                }}
                position="relative"
                className={`typePicker ${body_type === type.icon ? 'active' : ''}`}
              >
                <DmIcon
                  icon={icon}
                  icon_state={`${skin_color}_torso_${type.icon}_${gender}`}
                  width={'80px'}
                />
              </Box>
            </Tooltip>
          </Stack.Item>
        ))}
      </Stack>
    </Section>
  );
};

// Ethnicities have no hex color of their own — skin tone is a distinct torso sprite per
// ethnicity, not an RGB value, so each swatch renders a small real preview (same formula as the
// main preview/TypePicker) rather than a flat ColorBox with a color that doesn't exist.
const ColorOptions = () => {
  const { data, act } = useBackend<PickerData>();

  const { icon, gender, body_type, skin_color, skin_colors } = data;

  return (
    <Stack wrap>
      {skin_colors.map((color) => (
        <Stack.Item key={color.name}>
          <Tooltip content={color.name}>
            <Box
              onClick={() => act('color', { name: color.name })}
              position="relative"
              className={`typePicker ${skin_color === color.icon ? 'active' : ''}`}
            >
              <DmIcon
                icon={icon}
                icon_state={`${color.icon}_torso_${body_type}_${gender}`}
                width={'48px'}
              />
            </Box>
          </Tooltip>
        </Stack.Item>
      ))}
    </Stack>
  );
};

const EyeColorPicker = (props: {
  readonly close: () => void;
  readonly default_color: string;
}) => {
  const { act } = useBackend();
  const { close, default_color } = props;

  const [currentColor, setCurrentColor] = useState<HsvaColor>(
    hexToHsva(default_color || '#000000'),
  );

  return (
    <Modal width="100%">
      <Box width="350px">
        <Stack vertical>
          <Stack.Item>
            <ColorSelector
              color={currentColor}
              setColor={setCurrentColor}
              defaultColor={default_color}
              onConfirm={() => {
                close();
                act('eye_color', { color: hsvaToHex(currentColor) });
              }}
            />
          </Stack.Item>
        </Stack>
      </Box>
    </Modal>
  );
};
