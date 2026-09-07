import { useRef } from 'react';

import { useBackend } from '../backend';
import { Button, Section } from '../components';
import { Window } from '../layouts';
import {
  type Logo,
  type Preset,
  RichTextEditor,
  type RichTextEditorHandle,
} from './common/RichTextEditor';

type Data = {
  mode: 'pen' | 'crayon';
  logo_wy?: string;
  logo_wy_inv?: string;
  logo_uscm?: string;
  logo_upp?: string;
  logo_cmb?: string;
};

const FIELD = '<span class="paper_field"></span>';
const SIGN = '<span class="paper_sign_placeholder"></span>';
const DATE = '<span class="paper_date_placeholder"></span>';

const buildPresets = (wyLogo: string): Preset[] => {
  const wyHeader = (title: string) =>
    `<center><img src="${wyLogo}"><hr><font size="1"><i>The Company<br>Official Company Document<br><br><b>${title}</b></i></font><hr><h2>${FIELD}</h2></center>`;

  const wyFacilityDate = (extraYear = true) =>
    `<font size="1"><b>Facility:</b> USS Almayer ${FIELD}<br><b>Date:</b> ${DATE}${
      extraYear ? ' 2186' : ''
    }</font>`;

  return [
    {
      label: 'High Command Fax (Form X342)',
      html: `<font size="1"><center><b>United States Colonial Marine Corps.</b><br>Form X342<br>Situation Report</center><hr>Facility: USS Almayer<br>Date: ${DATE}<br>To: USCMC High Command - Missions Director<br>Subject: ${FIELD}<ul><li>${FIELD}</ul><hr>Signature: ${FIELD}</font>`,
    },
    {
      label: 'USCMC HR Complaint (Form Z343)',
      html: `<font size="1"><center><b>United States Colonial Marine Corps.</b><br>Form Z343<br>Complaint Form</center><hr>Facility: USS Almayer<br>Date: ${DATE}<br>Affected Person(s): ${FIELD}<br>Offender(s): ${FIELD}<br>Type of Complaint: ${FIELD}<br>Time of Incident: ${FIELD}<br>Reason for complaint:<ul><li>${FIELD}</ul>Preferred action:<br>[${FIELD}]Mediation<br>[${FIELD}]Reprimand<br>[${FIELD}]Fine/Paycut<br>[${FIELD}]Injunction<br>[${FIELD}]Demotion<hr>Signature: ${FIELD}<br>Commanding Officer/Executive Officer's Signature: ${FIELD}</font>`,
    },
    {
      label: 'CMO Drug Distribution (Doctors + Researchers, 339D)',
      html: `<b>Medication Distribution Form 339D</b><br><br>The Chief Medical Officer has authorized the following medications for distribution, in the form of pills or liquid containers, to doctors and researchers aboard the U.S.S Almayer:<br><br>- Replace with the drug you want to be authorised<br>- Replace with the drug you want to be authorised<br>- Replace with the drug you want to be authorised<br><br>Chief Medical Officer Signature: ${FIELD}`,
    },
    {
      label: 'CMO Drug Distribution (All Medical Personnel, 339B)',
      html: `<b>Medication Distribution Form 339B</b><br><br>The Chief Medical Officer has authorized the following medication(s) for distribution to the medical staff aboard the U.S.S Almayer, including field medics. The following medications can be provided in the form of pills or liquid containers:<br><br>- Replace with the drug you want to be authorised<br>- Replace with the drug you want to be authorised<br>- Replace with the drug you want to be authorised<br><br>Chief Medical Officer Signature: ${FIELD}`,
    },
    {
      label: 'Construction Permission Form (X347)',
      html: `<font size="1"><center><b>United States Colonial Marine Corps.</b><br>Form X347<br>Proposition of Construction</center><hr>Facility: USS Almayer<br>Date: ${DATE}<br>Location of Construction: ${FIELD}<br>Description of Proposal: ${FIELD}<ul><li>${FIELD}</ul><hr>Acting Commander Signature: ${FIELD}<br>Chief Engineers Signature: ${FIELD}<br>Department Head Signature: ${FIELD}</font>`,
    },
    {
      label: 'Research Journal',
      html: `${wyHeader('Research Journal')}<h3>Observations</h3>${wyFacilityDate()}<br><font size="1">${FIELD}</font><br><h3>Conclusion</h3><font size="1">${FIELD}</font><br><hr><font size="1">Research conducted by:<br>${FIELD}<br><br><i>The Company.</i></font>`,
    },
    {
      label: 'Research Report',
      html: `${wyHeader('Research Report')}<h3>Description</h3>${wyFacilityDate()}<br><font size="1">${FIELD}</font><br><h3>Analysis</h3><font size="1">${FIELD}</font><br><h3>Conclusion</h3><font size="1">${FIELD}</font><br><hr><font size="1">Research conducted by:<br>${FIELD}<br><br><i>The Company.</i></font>`,
    },
    {
      label: 'Research Interview',
      html: `${wyHeader('Interview Journal')}<h3>Interview background</h3>${wyFacilityDate()}<br><font size="1">${FIELD}</font><br><h3>Article</h3><font size="1">${FIELD}</font><br><hr><font size="1">Interview conducted by:<br>${FIELD}<br><br>Interviewee signature:<br>${FIELD}<br><br><i>The Company.</i></font>`,
    },
    {
      label: 'Research Experiment Proposal',
      html: `${wyHeader('Research Experiment Proposal')}<h3>Experiment Description</h3>${wyFacilityDate(false)}<br><br><font size="1"><b>Experiment Procedure</b><br>${FIELD}<br><br><b>Experiment Purpose</b><br>${FIELD}<br><br><hr>Researcher signature:<br>${FIELD}<br><br>Experiment Authorized by:<br>${FIELD}<br><br><i>The Company.</i></font>`,
    },
    {
      label: 'Research Experiment',
      html: `${wyHeader('Research Experiment')}<h3>Experiment Description</h3>${wyFacilityDate()}<br><font size="1">${FIELD}</font><br><h3>Experiment Results</h3><font size="1">${FIELD}</font><br><hr><font size="1">Researcher signature:<br>${FIELD}<br><br><i>The Company.</i></font>`,
    },
    {
      label: 'Research Volunteer (Human Experiment)',
      html: `${wyHeader('Human Research Experiment')}<h3>Experiment Description</h3><font size="1">${wyFacilityDate().replace(
        /<\/?font[^>]*>/g,
        '',
      )}<br><br><b>Purpose of Study</b><br>${FIELD}<br><br><b>Procedure of Study</b><br>${FIELD}<br><br><b>Upon completion, the volunteer will receive the following:</b><br>${FIELD}</font><h3>Experiment Results</h3><font size="1">${FIELD}</font><hr><h3>Volunteer information</h3><font size="1"><b>Full name:</b> ${FIELD}<br><b>Gender:</b> ${FIELD}<br><b>Age:</b> ${FIELD}<br><b>Occupation:</b> ${FIELD}<br><b>Rank (if any):</b> ${FIELD}<br><b>Notes:</b><br>${FIELD}</font><hr><font size="1"><i><b>Right to refuse or withdraw</b><br>The volunteer retains all rights to refuse or withdraw from the experiment at any time.<br><br><b>Right to ask questions and report concerns</b><br>The volunteer retains all rights to ask questions about the research before, during and after the experiment. The volunteer may ask and report any problems or concerns about the experiment.<br><br><b>Consent</b><br>The volunteer's signature below indicates that they have decided to participate in this experiment of their own free will, and that they have read and understood the information provided above.</i></font><hr><font size="1">Researcher signature:<br>${FIELD}<br><br>Volunteer signature:<br>${FIELD}<br><br><i>The Company.</i></font>`,
    },
    {
      label: 'PMC Recruitment (Whiteguard Solutions)',
      html: `<center><img src="${wyLogo}"><hr><b>Whiteguard Solutions Job Application Brief</b></center>Form 268/b23 "Whiteguard Solutions"<hr>Facility: USS Almayer Date: ${DATE}<br><br>I, ${FIELD}, enter into this contract of sound mind and body that post-enlistment with the United States Colonial Marines, if deemed mentally and physically able by appointed doctors of W-Y or any of its subsidiary companies, will be under contract as a Standard Private Military Contractor working on a reduced entry-level PMC rate of 50% the normal entry-level with the Company affiliate "Whiteguard Solutions" for a period of 4 years or until Whiteguard Solutions deems the contract void.<ul><li>I understand that should the conditions of a) "the signature provider's mental health or physical health be unable to complete their duties" or b) "the signature provider does not break trust" are not being met, "Whiteguard Solutions" may terminate my service.<li>In the second year of employment, pay may be fully raised to 60% of the standard entry-level pay of a member of "Whiteguard Solutions". On the third year of employment, the payment will be raised to 80% the pay of what a third-year PMC employee receives or full pay should the pay of a third-year PMC employee be less than the standard pay of an entry-level PMC employee. On the fourth year of employment, the payment will be raised to normal fourth year PMC employee levels. I understand that my pay may be reduced following an internal inquiry should I be unable to complete any of the duties assigned to me during my employment with "Whiteguard Solutions."<li>At the four years of service, I understand that a 10 Acre plot of land on a habitable planet owned by W-Y or any of its subsidiaries will be provided on the condition that I enlist in the registrar as an Auxiliary or Reserve member of a W-Y approved local militia, security or police organization. In accordance with such, I will serve such local militia, security or police organization in an auxiliary or regular capacity for a period of no less than 2 years.<li>Should the signature provider choose to not renegotiate their contract, a 5% severance payment based on the employee's last yearly wage will be made by The Company to the employee as a gesture of goodwill. Should the signature provider choose to renegotiate their contract and terms both parties sign to the renegotiated contract, a guaranteed bonus of 5% the pay of the new yearly wage will be made to the employee.<li>Acting on the behalf of "Whiteguard Solutions", W-Y additionally provides and guarantees all standard medical benefits that Standard, Entry-Level PMCs receive including Dental, Eyecare, and critical care for combat-related injuries while remaining in employment. I understand these services may cease, with the exception of critical care, if I am left unable to complete my employment terms.<li>I understand that should I fail to perform as to this agreement and all pursuant documents before 4 years, a minimum fee of one year's pay a normal entry-level PMC may be applied and the promised "10-acre plot of land" upon a habitable planet will not be granted to the signature provider. I understand that forfeit all right to bring a suit against the W-Y Corporation for any reason on the site. This agreement releases the Company from all liability relating to injuries and financial responsibilities for injuries that may occur on the site.</ul><font size="1"><i>I acknowledge that this is a preliminary agreement while still in the employ of another organization and understand additional forms ("Form 263, Form 264, Form 265, Form 266, Form 267, and Form 269") related to Healthcare, Lodging, Non-Disclosure, Liability, Payment method, and transfer to Whiteguard Solutions (a subsidiary of W-Y).</i></font><br><br>Signature: ${FIELD}<br><br>Corporate Liaison Signature: ${SIGN}`,
    },
    {
      label: 'Police Interrogation Report',
      html: `<center><b><u>Police Interrogation Report</u></b></center><center><font size="1"><u>USS Almayer</u></font></center><center><font size="1"><u>2nd Battalion, 4th Brigade, 'Falling Falcons'</u></font></center><font size="1"><i>An audio recording or transcript of the interview must be attached via label to this report to be considered valid! In the event of a criminal prosecution, this report is considered as evidence!</i></font><br><b>Interviewer's name: </b>${FIELD}<br><b>Rank: </b>${FIELD}<br><b>Interviewee's name: </b>${FIELD}<br><b>Rank: </b>${FIELD}<br><b>Designation</b><font size="1"><i>(Suspect/Witness/Other)</i></font><b>: </b>${FIELD}<br><b>Other personnel present: </b>${FIELD}<br><b><u>Interview Notes: </u></b>${FIELD}<hr><b>Interviewer's Signature: </b>${FIELD}`,
    },
    {
      label: 'Duty Log',
      html: `<center><font size="1"><u>USS Almayer</u></font></center><center><font size="1"><u>2nd Battalion, 4th Brigade, 'Falling Falcons'</u></font></center><center><font size="1">(location) Duty Log</font></center><hr>12:20 - CPL Jenning begins duty desk<br>12:35 - SSGT Hawkings visited duty desk asking after PFC Smith<br>${FIELD}`,
    },
    {
      label: 'Command Requisition Request Form',
      html: `<center><b><u>Command Requisition Request Form</u></b></center><center><font size="1"><i>To be filled out by any Officer to ask any Enlisted to fetch them supplies from requisitions</i></font></center><hr>Officer requesting supplies: ${FIELD}<br>Rank: ${FIELD}<br>Reason for request: ${FIELD}<br>Officer's signature: ${FIELD}<br>Items requested: <ul><li>${FIELD}<li>${FIELD}<li>${FIELD}</ul><hr><font size="1"><i>This must be stamped by Requisitions to prove the order was completed in full.</i></font>`,
    },
    {
      label: 'Pardon Form (B-229)',
      html: `<center><b><u>Official Pardon Form B-229</u></b></center><center><font size="1"><u>USS Almayer</u></font></center><center><font size="1"><u>2nd Battalion, 4th Brigade, 'Falling Falcons'</u></font></center><hr><font size="1"><i>The time of a crime must be known roughly, as well as exactly what the crimes were in accordance with U.S.C.M protocol 447, 284 (2144).</i></font><br>Date: ${FIELD}<br><br>Arresting Officer: ${FIELD}<br><br>Pardoned Individual: ${FIELD}<br><br>Listed Crimes:<br><br>&gt; ${FIELD}<br><br>&gt; ${FIELD}<br><br>&gt; ${FIELD}<br><br>Reason for Pardon: ${FIELD}<br><br>Time of Pardon: ${FIELD}<br><br>Commanding Officer's Name: ${FIELD}<br><font size="1"><i>The Commanding Officer may be held responsible for further criminal actions committed by those they pardon, and should High Command reverse the decision; they must ensure the condemned return to serve their time without incident. Failure to do so may result in removal and arrest at the discretion of High Command.</i></font><hr>Signature of Commanding Officer: ${FIELD}`,
    },
  ];
};

export const PaperEditor = () => {
  const { act, data } = useBackend<Data>();
  const { mode, logo_wy, logo_wy_inv, logo_uscm, logo_upp, logo_cmb } = data;
  const editorRef = useRef<RichTextEditorHandle>(null);

  const logos: Logo[] = [
    { label: 'Weyland-Yutani', html: `<img src="${logo_wy}">` },
    { label: 'Weyland-Yutani (inverted)', html: `<img src="${logo_wy_inv}">` },
    { label: 'USCM', html: `<img src="${logo_uscm}">` },
    { label: 'UPP', html: `<img src="${logo_upp}">` },
    { label: 'CMB', html: `<img src="${logo_cmb}">` },
  ];

  const presets = mode === 'pen' ? buildPresets(logo_wy ?? '') : [];

  return (
    <Window width={550} height={600} resizable theme="ntos">
      <Window.Content scrollable>
        <Section
          title="Write on Paper"
          buttons={
            <Button
              icon="check"
              onClick={() => {
                const html = editorRef.current?.getHtml();
                if (html) {
                  act('commit', { html });
                  editorRef.current?.clear();
                }
              }}
            >
              Commit to Paper
            </Button>
          }
        >
          <RichTextEditor
            ref={editorRef}
            mode={mode}
            logos={logos}
            presets={presets}
          />
        </Section>
      </Window.Content>
    </Window>
  );
};
