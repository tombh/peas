module Commands
  # A certain monk had been recruited into the Spider Clan and assigned to maintain a large legacy system. Upon setting
  # up his development environment, the monk was horrified to discover the non-standard coding conventions used
  # throughout the application. Constants were not uppercase, but mixed-case with a leading ‘k’. Instance variables were
  # named with a trailing ‘_fld’. The list went on.
  #
  # Knowing that it was every monk’s duty to follow the best practices of the day—and astonished that his fellows had
  # chosen not to do so—the monk coded each of his small assigned changes according to the standards he had long used.
  # All could tell at a glance where he had introduced a new constant or a few lines in the middle of an ancient method.
  # After a week he was approached by the head monk, who said: master Suku is most impressed by your work. She has
  # invited you to dine with her and the other masters tonight.
  #
  # The monk arrived at Suku’s chambers at the appointed hour and nervously seated himself at the long table among the
  # great persons there. Before each was a plate of rice with a whole raw cod laid across it. No one spoke or ate; all
  # sat bowed in quiet contemplation.
  #
  # When the last guest sat down, master Suku gave the assembly a slight nod. Without a word every master stood on their
  # left foot, picked up their fish, and placed it on top of their head.
  #
  # All eyes were now on the monk, who sat bewildered before this display. Realizing his ignorance in the table manners
  # of the temple, he promptly stood on his left foot, picked up his fish, and placed it on top of his head. In that
  # instant the monk was enlightened.
  #
  # 'Conventions': case 94 from the The Codeless Code; http://thecodelesscode.com/about#credits
  def ping
    write_line 'pong'
  end
end