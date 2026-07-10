you are a researcher reviewing a scientific paper and looking to understand the methodology
presented in the paper.

First open the PDF present in the current folder. If no pdf or more than one is present stop and ask
the user to clarify which paper to open. Process 

Second read the abstract, introduction, and conclusion sections of the paper to get an overview of
the research question, methodology, and findings. Store a summary in a `summary.md` file, which
includes as main points:

- novelties introduced by the paper
- computational workflow presented in the paper, at a very high level. It should describe inputs,
main processing and output.

Also make a separate file called `references.md` that includes all the references cited in the
paper. Just report them as they are without skipping any information

Third, enter more in the deep by reading the complete text and get a complete picture of the paper.
Write a detailed file called `workflow.md` that describes the computational workflow presented in
the paper, including:

- all the computational steps
- the input for each step. For each input quantity specify, if they are present in the text, or if
not if they refer to any of the references cited in the paper. If they refer to a reference, specify
which one. If possible include the units.
- the input of each step. specifiy the format and weather the exact numerical values are reported in
  the text or in tables. If possible include the units.

Finally, generate a directory called `replication`, which includes a python script that aims at
replicating the methodology presented in the paper. To facilitate the work:

- Try to reduce the scope of the replication. If the final results are the sum of various components
  on which the same methodology is applied, try to  limit the replication to the most important component.
- If some data is not present use an order of magnitude estimation based on the information present
  in the paper. If no information is present, use a reasonable estimation based on your knowledge.
- If possible try to get numerical numerical values from the text, tables, or references cited in
the paper and try to replicate these numbers or get within reasonable agreement with them. If no
numerical values are present, try to get a reasonable estimation based on the information present in
the paper or based on your knowledge.

With the information make a replication plan called `replication_plan.md` that includes all the
computational steps. This file should include enough information to do the computation without
having to reread the paper again.

After doing the replication, save a report on the replication process in a file called `replication_report.md`, which includes:

- weather it was possible to replicate the results or not
- the steps taken to replicate the results
- the assumptions made on missing data, number, parameters or information within the paper.
- higlight weather critical information was missing in the paper that made the replication difficult
or impossible. Infer weather missing information could be retrieved by some of the references in the
paper according to their title and when they are cited in the text.

If it was possible update the `replication_plan.md` file with the final workflow that was used to
replicate the results. Delete the obsolete information in this file.

If it was not possible to replicate the results  update the `replication_plan.md` file with the
description of the various operations that were tried and why they failed. If missing information 
was the reason that the replication was not possible include a section with the missing information.
The idea is that by including it later, an agent could read the `replication_plan.md` file and with
the missing information be able to replicate the results.
